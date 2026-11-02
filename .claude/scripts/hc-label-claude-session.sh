#!/bin/sh
# SessionStart フック: herdr-core の端末に、いま動いている Claude の会話ログの場所を印として付ける。
# Herdr の mod（redpen）が terminals() の labels からこの印を読み、最新の返答を取り出す。
# Herdr の外（HC_TERMINAL_ID なし）とサブエージェントでは何もしない。
# 失敗しても Claude Code の起動を止めない（常に exit 0）。
[ -n "${HC_TERMINAL_ID:-}" ] || exit 0
command -v hc >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
[ -z "$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)" ] || exit 0

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$transcript" ] || exit 0

hc label "$HC_TERMINAL_ID" "claude.transcript=$transcript" >/dev/null 2>&1 || true
exit 0
