#!/bin/bash
# codex-hud.sh: Codex CLI の隣のペインに、Claude Code の statusline.sh と同じ見た目の
# 複数行ステータス（セッション名 / モデル·effort / ctx バー / 5h / 7d）を出す。
#
# Codex の status_line は決まった項目名を1行に並べるだけで、自作スクリプトの出力を
# 描画できない（openai/codex#17827）。そこで Codex 自身が書いているローカルのデータを
# 読んで別プロセスとして描画する。ネットワークには出ない。会話本文は読まない。
#
#   ~/.codex/state_5.sqlite  threads テーブル … セッション名・モデル・effort・cwd・rollout パス
#   ~/.codex/sessions/**/rollout-*.jsonl      … token_count イベント（コンテキスト使用量・5h/7d 枠）
#
# 使い方:
#   codex-hud.sh                 # カレントディレクトリに紐づく最新セッションを 2 秒ごとに描画
#   codex-hud.sh --once          # 1 回描画して終了（動作確認用）
#   codex-hud.sh --interval 5    # 更新間隔（秒）
#   codex-hud.sh --cwd <path>    # 対象セッションを探すディレクトリを指定
#   codex-hud.sh --session <id>  # セッション ID を直接指定
#
# herdr での使い方: Codex のペインで prefix+minus（上下分割）→ 下のペインで codex-hud
#
# 制限:
#   - コスト（$）は Codex がローカルに書かないので出せない。代わりに累計トークン数を出す
#   - ctx% は「直前ターンで送った総トークン / モデルの窓」で概算する（Codex TUI の算出式は非公開）
#   - Codex の内部形式（sqlite のカラム・jsonl のイベント名）が変わると壊れる。
#     壊れたら「データなし」と出るので、check-parity.sh ではなくこの画面で気づく
set -u

INTERVAL=2
ONCE=0
TARGET_CWD="$PWD"
SESSION_ID=""
STATE_DB="${CODEX_HOME:-$HOME/.codex}/state_5.sqlite"

while [ $# -gt 0 ]; do
    case "$1" in
        --once) ONCE=1 ;;
        --interval) INTERVAL="$2"; shift ;;
        --cwd) TARGET_CWD="$2"; shift ;;
        --session) SESSION_ID="$2"; shift ;;
        -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
done

for cmd in sqlite3 jq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "codex-hud: $cmd が必要です" >&2; exit 2; }
done

# ── 配色・バー: .claude/statusline.sh と同じ定義（見た目を揃えるため意図的に複製）──
CYAN=$'\033[38;2;56;189;248m'
BLUE=$'\033[38;2;96;165;250m'
TEAL=$'\033[38;2;45;212;191m'
VIOLET=$'\033[38;2;129;140;248m'
ICE=$'\033[38;2;148;163;184m'
WARN=$'\033[38;2;96;165;250m'
RED=$'\033[38;2;240;138;138m'
RESET=$'\033[0m'

usage_color() {
    local p=$1 normal=$2
    if [ "$p" -ge 90 ]; then printf '%s' "$RED"
    elif [ "$p" -ge 70 ]; then printf '%s' "$WARN"
    else printf '%s' "$normal"
    fi
}

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

format_elapsed() {  # 秒
    local s=$1
    if [ "$s" -lt 60 ]; then echo "${s}s"
    elif [ "$s" -lt 3600 ]; then echo "$((s/60))m$((s%60))s"
    else echo "$((s/3600))h$(((s%3600)/60))m"
    fi
}

format_tokens() {  # 201751 → 202k
    local n=$1
    if [ "$n" -ge 1000000 ]; then printf '%.1fM' "$(echo "$n / 1000000" | bc -l)"
    elif [ "$n" -ge 1000 ]; then echo "$((n / 1000))k"
    else echo "$n"
    fi
}

quota_seg() {  # args: pct epoch label
    local pct=$1 epoch=$2 label=$3 color bar reset="" lbl now
    now=$(date +%s)
    printf -v lbl '%-3s' "$label"
    # 枠のリセット時刻を過ぎていたら、手元の値は古い（次のターンで Codex が書き直すまで分からない）
    if [ -n "$epoch" ] && [ "$epoch" != "null" ] && [ "$epoch" -le "$now" ] 2>/dev/null; then
        printf '%s' "${ICE}${lbl} $(make_bar 0 10) --%${RESET} ${ICE}↻reset済（次ターンで更新）${RESET}"
        return
    fi
    pct=$(printf '%.0f' "$pct")
    color=$(usage_color "$pct" "$TEAL")
    bar=$(make_bar "$pct" 10)
    if [ -n "$epoch" ] && [ "$epoch" != "0" ] && [ "$epoch" != "null" ]; then
        reset=" ${ICE}↻$(format_remaining "$epoch" "$now")${RESET}"
    fi
    printf '%s' "${ICE}${lbl} ${color}${bar} ${pct}%${RESET}${reset}"
}

# 5h/7d 枠はアカウント全体の値なので、対象セッションではなく「最近書かれた rollout」から拾う。
# token_count の rate_limits は null のことがあるため、非 null の最後のものを最近5本から探す。
latest_rate_limits() {
    local path hit
    while IFS= read -r path; do
        [ -f "$path" ] || continue
        # rate_limits があっても primary が null の記録（limit_id "premium" 等）は飛ばす
        hit=$(tail -c 400000 "$path" 2>/dev/null | grep '"token_count"' | grep '"primary":{' | tail -1)
        if [ -n "$hit" ]; then
            printf '%s' "$hit" | jq -r '
              .payload.rate_limits
              | [ (.primary.used_percent // ""), (.primary.resets_at // ""),
                  (.secondary.used_percent // ""), (.secondary.resets_at // "") ]
              | map(tostring) | join(" ")'
            return
        fi
    done < <(sqlite3 -readonly "$STATE_DB" \
        "SELECT rollout_path FROM threads ORDER BY updated_at DESC LIMIT 5" 2>/dev/null)
}

# ── データ取得 ──────────────────────────────────────────
# セッション選択: 指定 ID > cwd 一致の最新 > 全体の最新
pick_thread() {
    local where
    if [ -n "$SESSION_ID" ]; then
        where="id = '$SESSION_ID'"
    else
        where="archived = 0 AND cwd = '${TARGET_CWD//\'/\'\'}'"
    fi
    local row
    row=$(sqlite3 -readonly -separator $'\t' "$STATE_DB" \
        "SELECT id, rollout_path, COALESCE(NULLIF(name,''), title), COALESCE(model,''), COALESCE(reasoning_effort,''), created_at, cwd, tokens_used
         FROM threads WHERE $where ORDER BY updated_at DESC LIMIT 1" 2>/dev/null)
    if [ -z "$row" ] && [ -z "$SESSION_ID" ]; then
        row=$(sqlite3 -readonly -separator $'\t' "$STATE_DB" \
            "SELECT id, rollout_path, COALESCE(NULLIF(name,''), title), COALESCE(model,''), COALESCE(reasoning_effort,''), created_at, cwd, tokens_used
             FROM threads WHERE archived = 0 ORDER BY updated_at DESC LIMIT 1" 2>/dev/null)
    fi
    printf '%s' "$row"
}

render() {
    local row
    row=$(pick_thread)
    if [ -z "$row" ]; then
        printf '%s\n' "${ICE}codex-hud: セッションが見つからない（$STATE_DB）${RESET}"
        return
    fi
    local id rollout name model effort created cwd tokens_used
    IFS=$'\t' read -r id rollout name model effort created cwd tokens_used <<< "$row"

    # rollout 末尾から最新の token_count を拾う（ファイルは数 MB になるので末尾だけ読む）
    local tc=""
    if [ -f "$rollout" ]; then
        tc=$(tail -c 400000 "$rollout" 2>/dev/null | grep '"token_count"' | tail -1)
    fi
    local ctx_pct=0 ctx_win="" last_tok="" total_tok=""
    if [ -n "$tc" ]; then
        read -r ctx_win last_tok total_tok < <(
            printf '%s' "$tc" | jq -r '
              .payload.info
              | [ (.model_context_window // 0),
                  (.last_token_usage.total_tokens // 0),
                  (.total_token_usage.total_tokens // 0) ]
              | map(tostring) | join(" ")')
        if [ "${ctx_win:-0}" -gt 0 ] 2>/dev/null; then
            ctx_pct=$(( last_tok * 100 / ctx_win ))
        fi
    fi
    local five_pct="" five_rst="" seven_pct="" seven_rst=""
    read -r five_pct five_rst seven_pct seven_rst < <(latest_rate_limits)

    local now; now=$(date +%s)

    # 0行目: セッション名（/rename した name があれば優先、無ければ自動タイトル）
    local line0=""
    if [ -n "$name" ]; then
        name=$(printf '%s' "$name" | awk '{ if (length($0) > 48) print substr($0,1,47) "…"; else print $0 }')
        line0="${VIOLET}${name}${RESET}"
    fi

    # 1行目: モデル·effort + ディレクトリ + git ブランチ
    local display_dir
    display_dir=$(printf '%s' "$cwd" | sed "s|^$HOME|~|")
    local git_seg=""
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        local branch dirty=""
        branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && dirty="${VIOLET}*${RESET}"
            git_seg=" ${ICE}|${RESET} ${TEAL}${branch}${RESET}${dirty}"
        fi
    fi
    local model_label="${model:-codex}"
    [ -n "$effort" ] && model_label="${model_label}·${effort}"
    local line1="${CYAN}[${model_label}]${RESET} ${BLUE}${display_dir}${RESET}${git_seg}"

    # 2行目: ctx バー + 累計トークン + 経過時間
    local ctx_color ctx_bar
    ctx_color=$(usage_color "$ctx_pct" "$TEAL")
    ctx_bar=$(make_bar "$ctx_pct" 10)
    local line2="${ICE}ctx ${ctx_color}${ctx_bar} ${ctx_pct}%${RESET}"
    [ -n "$total_tok" ] && [ "$total_tok" != "0" ] && line2="${line2} ${ICE}| $(format_tokens "$total_tok") tok${RESET}"
    if [ -n "$created" ] && [ "$created" -gt 0 ] 2>/dev/null; then
        line2="${line2} ${ICE}| $(format_elapsed $(( now - created )))${RESET}"
    fi

    # 3・4行目: 5h / 7d
    local line3="" line4=""
    [ -n "$five_pct" ] && line3="$(quota_seg "$five_pct" "$five_rst" "5h")"
    [ -n "$seven_pct" ] && line4="$(quota_seg "$seven_pct" "$seven_rst" "7d")"
    [ -z "$five_pct" ] && [ -z "$seven_pct" ] && line3="${ICE}（5h/7d 枠の記録がまだ無い。最初のターンが終わると出る）${RESET}"

    [ -n "$line0" ] && printf '%s\n' "$line0"
    printf '%s\n' "$line1"
    printf '%s\n' "$line2"
    [ -n "$line3" ] && printf '%s\n' "$line3"
    [ -n "$line4" ] && printf '%s\n' "$line4"
}

if [ "$ONCE" -eq 1 ]; then
    render
    exit 0
fi

# ループ描画: カーソルを隠し、毎回ホームに戻って上書き → 末尾まで消す（画面全消去よりチラつかない）
printf '\033[?25l'
trap 'printf "\033[?25h\033[0m\n"; exit 0' INT TERM
while :; do
    out=$(render)
    printf '\033[H%s\033[J' "$out"
    sleep "$INTERVAL"
done
