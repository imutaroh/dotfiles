#!/usr/bin/env bash
# herdr-annotate の呼び出し口。エージェントの最新返答で Annotate ペインを開き直す。
#   direct（既定、Cmd+U = prefix+u、shell 型）: 対象を自動で決めて即開く
#       フォーカス中の Claude > そのタブで前回選んだ Claude > タブ内の先頭の Claude
#   pick（Cmd+Shift+U = prefix+shift+u、popup 型）: タブ内の Claude を fzf で選んでから開く
# どちらも同じタブの Annotate ペインを先に閉じる（連打しても1枚のまま中身だけ更新）。
# pick は popup の中で動くので、閉じる〜開き直すは popup が閉じたあとに裏のプロセスで行う
# （プラグイン呼び出しは「フォーカス中のペイン」を対象にするため、popup が残っていると外れる）。
set -euo pipefail

mode=${1:-direct}
cache="$HOME/.cache/herdr-annotate"
log="$cache/log"
mkdir -p "$cache"
printf '%s %s active_pane=%s active_tab=%s\n' "$(date +%T)" "$mode" \
  "${HERDR_ACTIVE_PANE_ID:-}" "${HERDR_ACTIVE_TAB_ID:-}" >>"$log"

panes=$(herdr pane list)
focused=$(jq -c '[.result.panes[] | select(.focused)][0] // {}' <<<"$panes")
tab=${HERDR_ACTIVE_TAB_ID:-$(jq -r '.tab_id // empty' <<<"$focused")}
active=${HERDR_ACTIVE_PANE_ID:-$(jq -r '.pane_id // empty' <<<"$focused")}
[ -n "$tab" ] || { echo "tab unknown" >>"$log"; exit 0; }
state="$cache/${tab//[^A-Za-z0-9_-]/_}"
saved=$(cat "$state" 2>/dev/null || true)

# タブ内のエージェント一覧（1行 = "pane_id<TAB>表示名"）
lines=$(jq -r --arg tab "$tab" '
  .result.panes[] | select(.tab_id == $tab and .agent)
  | "\(.pane_id)\t\(.terminal_title_stripped // .agent)  [\(.agent_status // "?")]"' <<<"$panes")
[ -n "$lines" ] || { echo "no agent in $tab" >>"$log"; exit 0; }
has() { awk -F'\t' -v id="$1" '$1 == id { found = 1 } END { exit !found }' <<<"$lines"; }

# 優先する候補: フォーカス中の Claude > 前回記録
prefer=""
if [ -n "$active" ] && has "$active"; then prefer=$active
elif [ -n "$saved" ] && has "$saved"; then prefer=$saved
fi

case $mode in
direct)
  agent=${prefer:-${lines%%$'\t'*}}
  ;;
pick)
  # 優先候補を先頭に並べ替え、fzf の初期カーソル（= 先頭行）に乗せる
  [ -n "$prefer" ] && lines=$(awk -F'\t' -v id="$prefer" '$1 == id; $1 != id { rest = rest $0 "\n" } END { printf "%s", rest }' <<<"$lines")
  agent=$(fzf --delimiter=$'\t' --with-nth=2 --no-sort --reverse --no-info \
              --prompt='Annotate ▸ ' --header='どの Claude の返答にコメントする？（Esc で中止）' \
              <<<"$lines" | cut -f1) || true
  [ -n "$agent" ] || { echo "cancelled" >>"$log"; exit 0; }
  ;;
*)
  echo "unknown mode: $mode" >>"$log"; exit 1 ;;
esac
printf '%s\n' "$agent" >"$state"
echo "chosen $agent ($mode)" >>"$log"

# Annotate を閉じる → 対象にフォーカス → プラグインで開き直す
reopen='
  tab=$1; agent=$2; log=$3; delay=$4
  sleep "$delay"
  herdr pane list | jq -r --arg tab "$tab" \
    ".result.panes[] | select(.tab_id == \$tab and .label == \"Annotate\") | .pane_id" |
    while read -r id; do herdr pane close "$id" >/dev/null; done
  for _ in 1 2 3 4 5; do
    herdr agent focus "$agent" >/dev/null 2>&1 || true
    herdr pane list | jq -e --arg a "$agent" ".result.panes[] | select(.pane_id == \$a and .focused)" >/dev/null && break
    sleep 0.2
  done
  herdr plugin action invoke annotate.last-newest >>"$log" 2>&1
  echo "$(date +%T) invoked for $agent" >>"$log"
'
if [ "$mode" = pick ]; then
  # popup を閉じてから実行する裏のプロセス。set -m で自分のプロセスグループに分離し、
  # popup 終了時の SIGHUP は nohup で無視する。
  set -m
  unset HERDR_ACTIVE_PANE_ID HERDR_PANE_ID
  nohup bash -c "$reopen" _ "$tab" "$agent" "$log" 0.4 >/dev/null 2>&1 </dev/null &
  disown
else
  bash -c "$reopen" _ "$tab" "$agent" "$log" 0
fi
exit 0
