#!/bin/sh
# Stop / PermissionRequest フック: Herdr のタブで動く Claude が返答を終えた時（done）と、
# 承認待ちで止まった時（blocked）に、macOS の通知を 1 件出す。
# 載せるのはタブ名・状態・本文の先頭 5 行まで。本文は、done なら最後の返答、blocked なら承認を求めている中身。
# 通知はこの Mac の中だけで、外部のサービスには何も送らない。
# Herdr の外（HC_TERMINAL_ID なし）とサブエージェントでは何もしない。
# 失敗しても Claude Code を止めない（常に exit 0、標準出力は空）。
[ -n "${HC_TERMINAL_ID:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v osascript >/dev/null 2>&1 || exit 0

input=$(cat)
[ -z "$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)" ] || exit 0

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
case "$event" in
  Stop)
    state="done"
    body=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
    if [ -z "$body" ]; then
      # 入力に返答が無い版では、会話ログの末尾から最後の返答の文章を拾う
      transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
      if [ -f "$transcript" ]; then
        body=$(tail -n 200 "$transcript" 2>/dev/null |
          jq -c 'select(.type == "assistant") | [.message.content[]? | select(.type == "text") | .text] | join("\n") | select(length > 0)' 2>/dev/null |
          tail -n 1 | jq -r '.' 2>/dev/null)
      fi
    fi
    ;;
  PermissionRequest)
    state=blocked
    body=$(printf '%s' "$input" | jq -r '
      .tool_input as $i
      | "承認待ち: \(.tool_name // "?")\n"
        + ($i.command // $i.questions[0]?.question // $i.file_path // $i.description // ($i | tostring))
    ' 2>/dev/null)
    ;;
  *) exit 0 ;;
esac

# タブ名は Herdr が端末に付ける where ラベル（「スペース名 / タブ名」）
tab=$(hc get "$HC_TERMINAL_ID" --json 2>/dev/null | jq -r '.labels.where // .title // empty' 2>/dev/null)
[ -n "$tab" ] || tab=$HC_TERMINAL_ID

# 空行を除いた先頭 5 行。1 行は 120 文字まで（macOS の awk はバイトで切って日本語を壊すので jq で切る）
body=$(printf '%s' "$body" | jq -Rrs 'split("\n") | map(select(test("\\S"))) | .[0:5] | map(.[0:120]) | join("\n")' 2>/dev/null)
[ -n "$body" ] || body="(本文なし)"

osascript \
  -e 'on run argv' \
  -e 'display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)' \
  -e 'end run' \
  "$tab" "$state" "$body" >/dev/null 2>&1 || true
exit 0
