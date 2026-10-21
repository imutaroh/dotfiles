#!/usr/bin/env bash
# サイドチャット: フォーカス中の Claude の会話を fork して popup で開く（Cmd+; = prefix+; から呼ぶ）。
# Claude Code Desktop の side chat（Cmd+;）の再現。メインの文脈を引き継いで何往復でも話せるが、
# fork なのでここで話した内容はメインの会話に入らない。plan モードなのでファイルも書き換えない。
# 開くたびにその時点のメインを fork し直す（前回のサイドチャットは引き継がない）。閉じるのは /exit か Ctrl+D。
set -euo pipefail

pane=${HERDR_ACTIVE_PANE_ID:-}
if [ -n "$pane" ]; then
  info=$(herdr pane get "$pane" | jq -c '.result.pane // .result')
else
  info=$(herdr pane list | jq -c '[.result.panes[] | select(.focused)][0] // {}')
fi

# herdr の Claude integration（SessionStart hook）が報告したセッション ID
session=$(jq -r 'select(.agent == "claude") | .agent_session.value // empty' <<<"$info")
cwd=$(jq -r '.cwd // empty' <<<"$info")

if [ -z "$session" ]; then
  echo "フォーカス中のペインに Claude がいません。Claude のペインで Cmd+; を押してください。"
  read -rsn1 -p "（何かキーを押すと閉じます）"
  exit 0
fi

# セッションはプロジェクトのディレクトリごとに保存されるので、メインと同じ cwd で resume する
cd "$cwd"
exec claude --resume "$session" --fork-session --permission-mode plan
