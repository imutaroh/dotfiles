#!/bin/bash
set -euo pipefail

# Claude Code の settings.json を「実環境 → dotfiles」へ取り込む。
#
# なぜ symlink ではないのか:
#   claude doctor などは settings.json を一時ファイル + rename で書き戻すため、
#   symlink はその時点で実ファイルに置き換わる。2026-07-27 に実際に発生し、
#   以降の設定変更が dotfiles に入らないまま乖離した。
#   symlink を張り直しても同じことが再発するので、コピー + 明示同期に切り替えた。
#
# 使い方:
#   ./sync-settings.sh          実環境の内容を dotfiles に取り込む
#   ./sync-settings.sh --check  差分の有無だけ調べる（差分あり = 終了コード 1）
#
# このリポジトリは公開しているので、次のものは取り込まない。実環境の値はそのまま残る。
#   autoMode: 非公開のリポジトリや個人データの置き場所を書くことがある
#   defaultMode と skipAutoPermissionPrompt: 複製した人が確認なしで auto モードに入らないようにする
#   enabledMcpjsonServers: 同名のサーバーを .mcp.json に置いたリポジトリで承認済みにならないようにする
#   herdr-agent-state.sh のフック: `herdr integration install claude` が各マシンのパスで作る
#   公式以外のプラグインとマーケットプレイス: 複製しただけで第三者のコードが有効にならないようにする
#   WebFetch の無条件許可: Read も無条件なので、Web ページの指示に騙されると読んだ内容を URL に載せて送れる
#   skillOverrides のうち claude.ai が同期するスキル（anthropic-skills:*）の行: アカウントごとの私的なスキル名が出る
#   model: /model を使うたびに書き換わる状態で、取り込むたびに差分になる。
#     追跡版はこのリポジトリのプロジェクト設定としても読まれるので、残すと dotfiles での作業だけ別のモデルに固定される

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/.claude/settings.json"
REPO="$DOTFILES_DIR/.claude/settings.json"

if [ ! -f "$LIVE" ]; then
    echo "settings.json が見つかりません: $LIVE" >&2
    exit 1
fi

FILTERED="$(mktemp)"
trap 'command rm -f "$FILTERED"' EXIT
jq '
  def official: endswith("@claude-plugins-official");
  del(.autoMode, .permissions.defaultMode, .skipAutoPermissionPrompt, .enabledMcpjsonServers, .model)
  | if .skillOverrides then
      .skillOverrides |= with_entries(select(.key | startswith("anthropic-skills:") | not))
      | if .skillOverrides == {} then del(.skillOverrides) else . end
    else . end
  | if .permissions.allow then
      .permissions.allow |= map(select(. != "WebFetch"))
    else . end
  | if .hooks then
      .hooks |= with_entries(.value |= (
        map(.hooks |= map(select((.command // "") | contains("herdr-agent-state.sh") | not)))
        | map(select(.hooks | length > 0))
      ))
    else . end
  | if .enabledPlugins then
      .enabledPlugins |= with_entries(select(.key | official))
    else . end
  | if .extraKnownMarketplaces then
      .extraKnownMarketplaces |= with_entries(select(.key == "claude-plugins-official"))
    else . end
' "$LIVE" > "$FILTERED"

if cmp -s "$FILTERED" "$REPO"; then
    echo "settings.json: 差分なし"
    exit 0
fi

if [ "${1:-}" = "--check" ]; then
    echo "settings.json: 実環境と dotfiles に差分あり（./sync-settings.sh で取り込む）"
    diff -u "$REPO" "$FILTERED" || true
    exit 1
fi

# 機密情報の混入チェック。settings.json は本来トークンを持たないが、
# 気づかずコミットすると公開リポジトリに載るため取り込み前に止める。
if grep -qiE '"[a-z0-9_-]*(api[_-]?key|token|secret|password)"[[:space:]]*:|sk-[A-Za-z0-9_-]{16}|github_pat_|gh[pousr]_[A-Za-z0-9]{16}|xox[abprs]-' "$FILTERED"; then
    echo "機密情報らしき値が含まれています。手動で確認してください: $LIVE" >&2
    exit 1
fi

cat "$FILTERED" > "$REPO"
echo "settings.json を取り込みました。差分を確認してコミットしてください:"
git -C "$DOTFILES_DIR" --no-pager diff --stat -- .claude/settings.json
