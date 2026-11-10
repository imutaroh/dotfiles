#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DISPLAY_DIR=$(echo "$CURRENT_DIR" | sed "s|^$HOME|~|")
# session_name: /rename したカスタム名、なければ AI 生成タイトル。どちらも無い間は absent
# 専用行に出すので上限は緩め（横幅からあふれる分は Claude Code 側が … で切る）
SESSION_NAME=$(echo "$input" | jq -r '.session_name // empty | if length > 48 then .[0:47] + "…" else . end')
# session_id: claude --resume <ID> / --fork-session に貼れるよう全桁（UUID 36 文字）で出す
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
# output style は default 以外のときだけ表示する
OUTPUT_STYLE=$(echo "$input" | jq -r '.output_style.name // empty')
[ "$OUTPUT_STYLE" = "default" ] && OUTPUT_STYLE=""

# ── 配色: 寒色ベース (24bit truecolor) ─────────────────────
CYAN=$'\033[38;2;56;189;248m'     # モデル名 (sky-400)
BLUE=$'\033[38;2;96;165;250m'     # ディレクトリ (blue-400)
TEAL=$'\033[38;2;45;212;191m'     # git ブランチ / バー通常 (teal-400)
VIOLET=$'\033[38;2;129;140;248m'  # dirty マーカー / セッション名 (indigo-400)
ICE=$'\033[38;2;148;163;184m'     # ラベル・区切り・補助情報 (slate-400)
WARN=$'\033[38;2;96;165;250m'     # 70%+ 警告 (明るい青)
RED=$'\033[38;2;240;138;138m'     # 90%+ 危険 (控えめコーラル)
RESET=$'\033[0m'

# 使用率に応じた色 (90%+ コーラル / 70%+ 明るい青 / それ以外 通常色)
usage_color() {
    local p=$1 normal=$2
    if [ "$p" -ge 90 ]; then printf '%s' "$RED"
    elif [ "$p" -ge 70 ]; then printf '%s' "$WARN"
    else printf '%s' "$normal"
    fi
}

# プログレスバー (▓=使用 ░=空) を組み立てる
make_bar() {
    local pct=$1 width=$2
    local filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    local empty=$(( width - filled ))
    local fill="" pad=""
    [ "$filled" -gt 0 ] && printf -v fill "%${filled}s"
    [ "$empty" -gt 0 ] && printf -v pad "%${empty}s"
    printf '%s' "${fill// /▓}${pad// /░}"
}

# 残り時間 (epoch差) を "23m" "1h30m" "2d14h" 等にフォーマット
format_remaining() {
    local diff=$(( $1 - $2 ))
    if [ "$diff" -le 0 ]; then echo "0m"
    elif [ "$diff" -lt 3600 ]; then echo "$((diff / 60))m"
    elif [ "$diff" -lt 86400 ]; then
        local h=$((diff / 3600)) m=$(((diff % 3600) / 60))
        if [ "$m" -eq 0 ]; then echo "${h}h"; else echo "${h}h${m}m"; fi
    else
        local d=$((diff / 86400)) h=$(((diff % 86400) / 3600))
        if [ "$h" -eq 0 ]; then echo "${d}d"; else echo "${d}d${h}h"; fi
    fi
}

# 経過時間 (ms) を "45s" "7m3s" "1h2m" 等にフォーマット
format_elapsed() {
    local s=$(( $1 / 1000 ))
    if [ "$s" -lt 60 ]; then echo "${s}s"
    elif [ "$s" -lt 3600 ]; then echo "$((s/60))m$((s%60))s"
    else echo "$((s/3600))h$(((s%3600)/60))m"
    fi
}

NOW=$(date +%s)

# ── 0行目: セッション名（狭いペインでも見えるよう専用行）──
LINE0=""
[ -n "$SESSION_NAME" ] && LINE0="${VIOLET}${SESSION_NAME}${RESET}"

# ── 0b行目: セッション ID（切り詰めると貼れないので専用行・全桁）──
LINE0B=""
[ -n "$SESSION_ID" ] && LINE0B="${ICE}${SESSION_ID}${RESET}"

# ── 1行目: モデル·effort（effort-auto が有効なら省略）+ ディレクトリ + git ブランチ + output style ──
GIT_SEG=""
# CURRENT_DIR はクローンした他人のリポジトリの中にもなり得る。そのリポジトリの config に
# 書かれた core.fsmonitor 等をコマンドとして実行させないよう、実行系の設定を無効化して呼ぶ
safe_git() {
    git -c core.fsmonitor=false -c core.hooksPath=/dev/null -c safe.bareRepository=explicit \
        --no-optional-locks -C "$CURRENT_DIR" "$@"
}
if safe_git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(safe_git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        DIRTY=""
        # filter.<name>.clean は -c で無効にできず status が実行するので、リポジトリ側に定義があれば判定を省く
        if ! safe_git config --show-scope --get-regexp '^filter\.' 2>/dev/null | grep -qE '^(local|worktree)[[:space:]]' \
            && [ -n "$(safe_git status --porcelain 2>/dev/null)" ]; then
            DIRTY="${VIOLET}*${RESET}"
        fi
        GIT_SEG=" ${ICE}|${RESET} ${TEAL}${BRANCH}${RESET}${DIRTY}"
    fi
fi
# effort-auto プラグインは依頼ごとに深さを判定し、送信の直前に差し替える。
# .effort.level は差し替える前の基準値で実際の深さとずれるので、有効なときは出さない（実際の深さはプラグインが表示する）
# 有効かどうかは Claude Code と同じ user < project < local の後勝ちで読む。読めないときは無効扱いで、基準値を出す
effort_auto_enabled() {
    local project_dir file files=()
    project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir')
    for file in "$HOME/.claude/settings.json" "$project_dir/.claude/settings.json" "$project_dir/.claude/settings.local.json"; do
        [ -f "$file" ] && files+=("$file")
    done
    [ "${#files[@]}" -gt 0 ] || return 1
    [ "$(jq -s '[.[].enabledPlugins["effort-auto@hide10"]? | select(. != null)] | last | . != null and . != false' "${files[@]}" 2>/dev/null)" = "true" ]
}
MODEL_LABEL="$MODEL"
[ -n "$EFFORT" ] && ! effort_auto_enabled && MODEL_LABEL="${MODEL}·${EFFORT}"
STYLE_SEG=""
[ -n "$OUTPUT_STYLE" ] && STYLE_SEG=" ${ICE}|${RESET} ${ICE}${OUTPUT_STYLE}${RESET}"
LINE1="${CYAN}[${MODEL_LABEL}]${RESET} ${BLUE}${DISPLAY_DIR}${RESET}${GIT_SEG}${STYLE_SEG}"

# ── 2行目: ctx バー + コスト + セッション経過時間 ──────────
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$PCT" ]; then
    # used_percentage が無い時は current_usage から算出
    CW_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
    USAGE=$(echo "$input" | jq '.context_window.current_usage')
    if [ "$USAGE" != "null" ] && [ "$CW_SIZE" != "0" ]; then
        TOK=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
        PCT=$(( TOK * 100 / CW_SIZE ))
    else
        PCT=0
    fi
fi
PCT=${PCT%.*}   # 小数切り捨て

CTX_COLOR=$(usage_color "$PCT" "$TEAL")
CTX_BAR=$(make_bar "$PCT" 10)
LINE2="${ICE}ctx ${CTX_COLOR}${CTX_BAR} ${PCT}%${RESET}"

COST=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
[ -n "$COST" ] && LINE2="${LINE2} ${ICE}| $(printf '$%.2f' "$COST")${RESET}"

DUR_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
[ -n "$DUR_MS" ] && [ "$DUR_MS" != "0" ] && LINE2="${LINE2} ${ICE}| $(format_elapsed "$DUR_MS")${RESET}"

# ── 3行目: 5h / 7d レート制限 (バー + % + リセット残り) ────
quota_seg() {  # args: pct epoch label
    local pct=$1 epoch=$2 label=$3 color bar reset="" lbl
    pct=$(printf '%.0f' "$pct")
    printf -v lbl '%-3s' "$label"   # ラベル幅を ctx に合わせて揃える
    color=$(usage_color "$pct" "$TEAL")
    bar=$(make_bar "$pct" 10)
    if [ -n "$epoch" ] && [ "$epoch" != "0" ] && [ "$epoch" != "null" ]; then
        reset=" ${ICE}↻$(format_remaining "$epoch" "$NOW")${RESET}"
    fi
    printf '%s' "${ICE}${lbl} ${color}${bar} ${pct}%${RESET}${reset}"
}

FIVE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_RST=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_RST=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

LINE3=""
[ -n "$FIVE_PCT" ] && LINE3="$(quota_seg "$FIVE_PCT" "$FIVE_RST" "5h")"
LINE4=""
[ -n "$SEVEN_PCT" ] && LINE4="$(quota_seg "$SEVEN_PCT" "$SEVEN_RST" "7d")"

# ── 出力: 縦に並べる (空の行はスキップ) ───────────────────
#   0行目: セッション名（/rename 名 or AI 生成タイトル、未生成なら行ごと省略）
#   0b行目: セッション ID（全桁。入力に無ければ行ごと省略）
#   1行目: モデル·effort（effort-auto が有効なら省略）+ ディレクトリ + git ブランチ + output style（非default時のみ）
#   2行目: ctx バー + コスト + セッション経過時間
#   3行目: 5h レート制限バー + リセット残り
#   4行目: 7d レート制限バー + リセット残り
[ -n "$LINE0" ] && echo -e "$LINE0"
[ -n "$LINE0B" ] && echo -e "$LINE0B"
echo -e "$LINE1"
echo -e "$LINE2"
[ -n "$LINE3" ] && echo -e "$LINE3"
[ -n "$LINE4" ] && echo -e "$LINE4"
exit 0  # 最終行の && が偽でも非0終了させない
