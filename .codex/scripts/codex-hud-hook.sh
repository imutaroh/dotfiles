#!/bin/bash
# codex-hud-hook.sh: Codex の UserPromptSubmit hook から呼ばれ、codex-hud.sh の 5 行を
# `systemMessage` として返す。Codex はこれを UI に（警告スタイルで）表示する。
#
# なぜ hook か: Codex 本体の status_line は自作出力を描けない（openai/codex#17827）。
# systemMessage なら Codex のタブの中に出せる。ただし固定表示ではなく、送信のたびに
# 会話欄へ 1 ブロック出て上へ流れる。常時表示が要るなら別ペインで codex-hud を使う。
#
# 注意:
#   - additionalContext は返さない（モデルに渡ってトークンを消費するため）。表示だけが目的
#   - 色（ANSI）は Codex が描かない前提で外す。バー文字 ▓░ はそのまま
#   - 失敗しても空 JSON を返して終了コード 0（hook の失敗で送信を止めない）
#
# hooks.json での定義は ../hook-fragments/codex-hud.json を参照。/hooks で本人が trust するまで動かない。
set -u

HUD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/codex-hud.sh"

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

args=(--once)
[ -n "$session_id" ] && args+=(--session "$session_id")
[ -n "$cwd" ] && args+=(--cwd "$cwd")

text=$(bash "$HUD" "${args[@]}" 2>/dev/null | sed $'s/\033\\[[0-9;]*m//g')

if [ -z "$text" ]; then
    echo '{}'
    exit 0
fi

jq -n --arg m "$text" '{systemMessage: $m}'
