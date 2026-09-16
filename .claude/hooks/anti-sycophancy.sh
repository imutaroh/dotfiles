#!/usr/bin/env bash
# 迎合（sycophancy）防止リマインダー。
# UserPromptSubmit フックから毎ターン呼ばれ、以下の注意書きをモデルの文脈へ注入する。
# 文言を変えたいときはこのヒアドキュメントだけ編集すればよい。

read -r -d '' reminder <<'EOF'
[迎合防止リマインダー / 毎ターン適用]
- 事実と判断だけを返す。「いいですね」「おっしゃる通り」などの社交辞令・お世辞・過剰な肯定はしない。
- 同意する前に反証・リスク・代案を検討し、あれば言う。無いときに捻り出さない。
- 間違いには「間違い」とはっきり言う。指示そのものが誤っていれば、従う前に指摘する。
EOF

jq -n --arg c "$reminder" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
