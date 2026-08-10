#!/usr/bin/env bash
# /close スキル用: 現セッションの生ログ(jsonl)を、レビュー可能な markdown に変換する。
#
# なぜ ctx を使わないか:
#   ctx は設計上 tool_call の入力 / tool_output の中身 / AskUserQuestion の回答を
#   保存しない（`ctx docs show provider-import-policy` の "should not store" 参照）。
#   「何を指示して Claude が何をやったか」を見る用途では材料の大半が欠落する。
#   生ログには全部残っているので、そちらを直接読む。
#
# 使い方:
#   extract-session.sh [出力先パス] [対象jsonl]
#   引数省略時: 出力先 = .claude/tmp/close/session-<id>.md
#               対象   = 現在の作業ディレクトリに対応する最新セッション
set -euo pipefail

TOOL_INPUT_MAX=${TOOL_INPUT_MAX:-800}
TOOL_RESULT_MAX=${TOOL_RESULT_MAX:-800}

SESSION_JSONL=${2:-}
if [ -z "$SESSION_JSONL" ]; then
  SLUG="${PWD//\//-}"
  SESSION_JSONL=$(ls -t "$HOME/.claude/projects/$SLUG"/*.jsonl 2>/dev/null | head -1 || true)
  # 作業ディレクトリに対応するプロジェクトが無ければ、全体から最新を拾う
  [ -z "$SESSION_JSONL" ] && SESSION_JSONL=$(ls -t "$HOME"/.claude/projects/*/*.jsonl | head -1)
fi

if [ ! -f "$SESSION_JSONL" ]; then
  echo "ERROR: セッションログが見つかりません: $SESSION_JSONL" >&2
  exit 1
fi

SID=$(basename "$SESSION_JSONL" .jsonl)
OUT=${1:-.claude/tmp/close/session-$SID.md}
mkdir -p "$(dirname "$OUT")"

{
  echo "# セッション生ログ (レビュー用)"
  echo
  echo "- session_id: \`$SID\`"
  echo "- source: \`$SESSION_JSONL\`"
  echo "- tool 入力は先頭 ${TOOL_INPUT_MAX} 文字 / tool 結果は先頭 ${TOOL_RESULT_MAX} 文字で打ち切っている"
  echo "- thinking ブロックは暗号化されており本文が存在しないため含めていない"
  echo
} > "$OUT"

jq -r --argjson imax "$TOOL_INPUT_MAX" --argjson rmax "$TOOL_RESULT_MAX" '
  select(.type=="user" or .type=="assistant")
  | .timestamp as $ts | .type as $role
  | (if (.message.content|type)=="string"
     then [{type:"text", text:.message.content}]
     else (.message.content // []) end)
  | .[]?
  | if .type=="text" and ((.text // "")|length) > 0 then
      "\n## \($role) [\($ts)]\n" + (.text | gsub("(?s)<system-reminder>.*?</system-reminder>"; "«system-reminder 省略»"))
    elif .type=="tool_use" then
      "\n### TOOL: \(.name)\n```\n\((.input|tostring)[:$imax])\n```"
    elif .type=="tool_result" then
      "\n### RESULT\n```\n\((
        if (.content|type)=="array"
        then ([.content[]? | select(.type=="text") | .text] | join("\n"))
        else (.content|tostring) end
      )[:$rmax])\n```"
    else empty end
' "$SESSION_JSONL" >> "$OUT"

echo "$OUT"
wc -c "$OUT" | awk '{print "bytes: " $1}'
