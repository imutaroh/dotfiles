#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Focus Space Agent
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName herdr

# Documentation:
# @raycast.description 今フォーカス中の herdr Space にいる AI エージェントのペインへ一撃で飛ぶ（アクティブタブのエージェント優先）。

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ws_json=$(herdr workspace list 2>/dev/null)
if [ -z "$ws_json" ]; then
  echo "herdr サーバに接続できません"
  exit 1
fi

ws=$(echo "$ws_json" | jq -r '.result.workspaces[] | select(.focused) | .workspace_id')
tab=$(echo "$ws_json" | jq -r '.result.workspaces[] | select(.focused) | .active_tab_id')

# フォーカス中 Space のエージェントを取得（アクティブタブにいるものを先頭に）
target=$(herdr agent list | jq -r --arg ws "$ws" --arg tab "$tab" \
  '[.result.agents[] | select(.workspace_id==$ws)] | (map(select(.tab_id==$tab)) + .)[0].terminal_id // empty')

if [ -z "$target" ]; then
  echo "この Space にエージェントがいません"
  exit 0
fi

herdr agent focus "$target"
open -a Ghostty
