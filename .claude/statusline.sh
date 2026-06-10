#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DISPLAY_DIR=$(echo "$CURRENT_DIR" | sed "s|^$HOME|~|")

# ── 配色: 寒色ベース (24bit truecolor) ─────────────────────
CYAN=$'\033[38;2;56;189;248m'     # モデル名 (sky-400)
BLUE=$'\033[38;2;96;165;250m'     # ディレクトリ (blue-400)
TEAL=$'\033[38;2;45;212;191m'     # git ブランチ (teal-400)
VIOLET=$'\033[38;2;129;140;248m'  # dirty マーカー / ctx 通常値 (indigo-400)
ICE=$'\033[38;2;148;163;184m'     # ラベル・区切り (slate-400, dim)
WARN=$'\033[38;2;96;165;250m'     # 70%+ 警告 (明るい青)
RED=$'\033[38;2;240;138;138m'     # 90%+ 危険 (輝度高めの控えめコーラル)
RESET=$'\033[0m'

# 使用率に応じた色を返す (90%+ 赤 / 70%+ 明るい青 / それ以外 通常色)
usage_color() {
    local p=$1 normal=$2
    if [ "$p" -ge 90 ]; then printf '%s' "$RED"
    elif [ "$p" -ge 70 ]; then printf '%s' "$WARN"
    else printf '%s' "$normal"
    fi
}

# 相対時間をフォーマット (epoch → "23m", "1h30m", "6d3h" 等)
format_remaining() {
    local diff=$(( $1 - $2 ))
    if [ "$diff" -le 0 ]; then
        echo "0m"
    elif [ "$diff" -lt 3600 ]; then
        echo "$((diff / 60))m"
    elif [ "$diff" -lt 86400 ]; then
        local h=$((diff / 3600))
        local m=$(((diff % 3600) / 60))
        if [ "$m" -eq 0 ]; then echo "${h}h"; else echo "${h}h${m}m"; fi
    else
        local d=$((diff / 86400))
        local h=$(((diff % 86400) / 3600))
        if [ "$h" -eq 0 ]; then echo "${d}d"; else echo "${d}d${h}h"; fi
    fi
}

# ── コンテキスト & クォータ (4行目用パーツを組み立て) ──────
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

USAGE_LINE=""
if [ "$USAGE" != "null" ] && [ "$CONTEXT_SIZE" != "null" ] && [ "$CONTEXT_SIZE" != "0" ]; then
    CURRENT_TOKENS=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    PERCENT=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
    CTX_COLOR=$(usage_color "$PERCENT" "$VIOLET")
    USAGE_LINE="${ICE}ctx ${CTX_COLOR}${PERCENT}%${RESET}"

    # Quota キャッシュ読み取り・バックグラウンド更新
    QUOTA_CACHE="/tmp/claude-quota-cache"
    QUOTA_CACHE_TTL=60

    # キャッシュの経過秒数を取得
    if [ -f "$QUOTA_CACHE" ]; then
        CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$QUOTA_CACHE") ))
    else
        CACHE_AGE=$(( QUOTA_CACHE_TTL + 1 ))
    fi

    # キャッシュが古い場合はバックグラウンドで更新
    if [ "$CACHE_AGE" -gt "$QUOTA_CACHE_TTL" ]; then
        (
            QUOTA_JSON=$(bash ~/.claude/scripts/fetch_usage.sh 2>/dev/null)
            if echo "$QUOTA_JSON" | jq -e '.five_hour' > /dev/null 2>&1; then
                FIVE_H=$(echo "$QUOTA_JSON" | jq -r '.five_hour.utilization')
                SEVEN_D=$(echo "$QUOTA_JSON" | jq -r '.seven_day.utilization')
                # リセット時刻を epoch に変換 (macOS date)
                FIVE_H_RESET=$(echo "$QUOTA_JSON" | jq -r '.five_hour.resets_at' | sed 's/\.[0-9]*//' | sed 's/\([-+][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')
                FIVE_H_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$FIVE_H_RESET" "+%s" 2>/dev/null || echo "0")
                SEVEN_D_RESET=$(echo "$QUOTA_JSON" | jq -r '.seven_day.resets_at' | sed 's/\.[0-9]*//' | sed 's/\([-+][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')
                SEVEN_D_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$SEVEN_D_RESET" "+%s" 2>/dev/null || echo "0")
                echo "$FIVE_H $SEVEN_D $FIVE_H_EPOCH $SEVEN_D_EPOCH" > "$QUOTA_CACHE"
            fi
        ) &
    fi

    # キャッシュから quota 値を読み取り
    if [ -f "$QUOTA_CACHE" ]; then
        read -r FIVE_H SEVEN_D FIVE_H_EPOCH SEVEN_D_EPOCH < "$QUOTA_CACHE"
        if [ -n "$FIVE_H" ] && [ -n "$SEVEN_D" ]; then
            FIVE_H_INT=$(printf "%.0f" "$FIVE_H")
            SEVEN_D_INT=$(printf "%.0f" "$SEVEN_D")
            NOW=$(date +%s)

            # 5h の色分け + リセットまでの残り時間 (常時表示)
            FIVE_H_COLOR=$(usage_color "$FIVE_H_INT" "$ICE")
            FIVE_H_RESET_STR=""
            if [ -n "$FIVE_H_EPOCH" ] && [ "$FIVE_H_EPOCH" != "0" ]; then
                FIVE_H_RESET_STR=" ↻$(format_remaining "$FIVE_H_EPOCH" "$NOW")"
            fi

            # 7d の色分け + リセットまでの残り時間 (常時表示)
            SEVEN_D_COLOR=$(usage_color "$SEVEN_D_INT" "$ICE")
            SEVEN_D_RESET_STR=""
            if [ -n "$SEVEN_D_EPOCH" ] && [ "$SEVEN_D_EPOCH" != "0" ]; then
                SEVEN_D_RESET_STR=" ↻$(format_remaining "$SEVEN_D_EPOCH" "$NOW")"
            fi

            USAGE_LINE="${USAGE_LINE} ${ICE}· 5h ${FIVE_H_COLOR}${FIVE_H_INT}%${FIVE_H_RESET_STR}${RESET} ${ICE}· 7d ${SEVEN_D_COLOR}${SEVEN_D_INT}%${SEVEN_D_RESET_STR}${RESET}"
        fi
    fi
fi

# ── git ブランチ + dirty (3行目) ─────────────────────────
GIT_LINE=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        DIRTY=""
        if [ -n "$(git -C "$CURRENT_DIR" status --porcelain 2>/dev/null)" ]; then
            DIRTY="${VIOLET}*${RESET}"
        fi
        GIT_LINE="${TEAL}${BRANCH}${RESET}${DIRTY}"
    fi
fi

# ── 出力: 縦に並べる (空の行はスキップ) ───────────────────
#   1行目: モデル名 + 作業ディレクトリ
#   2行目: git ブランチ + dirty
#   3行目: ctx / 5h / 7d 使用率 (5h・7d はリセットまでの残り時間つき)
echo -e "${CYAN}${MODEL}${RESET}  ${BLUE}${DISPLAY_DIR}${RESET}"
[ -n "$GIT_LINE" ] && echo -e "$GIT_LINE"
[ -n "$USAGE_LINE" ] && echo -e "$USAGE_LINE"
