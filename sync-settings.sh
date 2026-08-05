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

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/.claude/settings.json"
REPO="$DOTFILES_DIR/.claude/settings.json"

if [ ! -f "$LIVE" ]; then
    echo "settings.json が見つかりません: $LIVE" >&2
    exit 1
fi

if cmp -s "$LIVE" "$REPO"; then
    echo "settings.json: 差分なし"
    exit 0
fi

if [ "${1:-}" = "--check" ]; then
    echo "settings.json: 実環境と dotfiles に差分あり（./sync-settings.sh で取り込む）"
    diff -u "$REPO" "$LIVE" || true
    exit 1
fi

# 機密情報の混入チェック。settings.json は本来トークンを持たないが、
# 気づかずコミットすると公開リポジトリに載るため取り込み前に止める。
if grep -qiE '"(api[_-]?key|token|secret|password)"[[:space:]]*:|sk-[A-Za-z0-9]{16}|ghp_[A-Za-z0-9]{16}' "$LIVE"; then
    echo "機密情報らしき値が含まれています。手動で確認してください: $LIVE" >&2
    exit 1
fi

cp "$LIVE" "$REPO"
echo "settings.json を取り込みました。差分を確認してコミットしてください:"
git -C "$DOTFILES_DIR" --no-pager diff --stat -- .claude/settings.json
