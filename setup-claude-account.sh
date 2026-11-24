#!/bin/bash
set -uo pipefail

# Claude Code のアカウントまわりを入れ直す（新しい Mac、または /login で別アカウントに切り替えたあと）。
#
# このスクリプトがやること（何度走らせても同じ結果になる）:
#   1. ユーザー全体（-s user）の MCP サーバーを登録する。既にある名前は飛ばす
#   2. 有効にしているプラグインと、その入手先（マーケットプレイス）を入れる。既にあるものは飛ばす
#   3. 最後に `claude mcp list` で接続状態を出す
#
# やらないこと（手で行う。手順は .claude/account-setup.md）:
#   - MCP サーバーの OAuth。Claude Code の中で /mcp を開いて認証する
#   - claude.ai のコネクタ（Slack・Notion・Gmail など）。アカウント側の設定で、ブラウザで繋ぐ
#   - Claude in Chrome の拡張のサインインと接続
#
# 既にあるサーバーを remove して入れ直すことはしない。消すと保存済みの OAuth も消えるため。
# URL を変えたいときは、手で `claude mcp remove -s user <名前>` してから走らせる。
#
# 公開リポジトリなので、会社や私的なサーバーはここに書かない。次のファイルに 1 行 1 本で書く（追跡しない）:
#   ${CLAUDE_PRIVATE_MCP_FILE:-~/dotfiles-private/claude/mcp-servers.tsv}
#   書式: <名前><TAB><transport（http / sse）><TAB><URL>。# で始まる行と空行は読まない
#   ファイルが無ければ、その分を飛ばすだけで失敗にはしない
#
# 使い方:
#   ./setup-claude-account.sh          登録とインストールを行う
#   ./setup-claude-account.sh --check  足りないものを表示するだけ（足りなければ終了コード 1）

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PRIVATE_MCP_FILE="${CLAUDE_PRIVATE_MCP_FILE:-$HOME/dotfiles-private/claude/mcp-servers.tsv}"

CHECK=0
case "${1:-}" in
    --check) CHECK=1 ;;
    "") ;;
    *) echo "使い方: $0 [--check]" >&2; exit 2 ;;
esac

# 公開してよい MCP サーバー（名前 transport URL）
PUBLIC_MCP_SERVERS="
linear http https://mcp.linear.app/mcp
canva http https://mcp.canva.com/mcp
"

# 入れるプラグイン。settings.json の enabledPlugins で true のもの。
# マーケットプレイスは「名前 GitHub のリポジトリ」で先に足す。
# 公式も書いておく（入れたばかりの環境では一覧が空で、update するまで中のプラグインが見つからない）
MARKETPLACES="
claude-plugins-official anthropics/claude-plugins-official
openai-codex openai/codex-plugin-cc
"
PLUGINS="
claude-security@claude-plugins-official
gopls-lsp@claude-plugins-official
codex@openai-codex
"

if ! command -v claude >/dev/null 2>&1; then
    echo "claude が見つかりません。先に setup.sh で Claude Code を入れてください" >&2
    exit 1
fi

missing=0
failed=0

add_mcp() {
    local name="$1" transport="$2" url="$3"
    if claude mcp get "$name" >/dev/null 2>&1; then
        echo "  ok    ${name}（登録済み）"
        return
    fi
    if [ "$CHECK" -eq 1 ]; then
        echo "  不足  $name"
        missing=1
        return
    fi
    if claude mcp add -s user -t "$transport" "$name" "$url" >/dev/null; then
        echo "  追加  $name"
    else
        echo "  失敗  $name" >&2
        failed=1
    fi
}

echo "== MCP サーバー（ユーザー全体）"
while read -r name transport url; do
    [ -n "${name:-}" ] || continue
    add_mcp "$name" "$transport" "$url"
done <<< "$PUBLIC_MCP_SERVERS"

if [ -f "$PRIVATE_MCP_FILE" ]; then
    while IFS=$'\t' read -r name transport url; do
        case "${name:-}" in ''|\#*) continue ;; esac
        if [ -z "${transport:-}" ] || [ -z "${url:-}" ]; then
            echo "  読めない行を飛ばしました（タブ区切りで 3 列）: $name" >&2
            continue
        fi
        add_mcp "$name" "$transport" "$url"
    done < "$PRIVATE_MCP_FILE"
else
    echo "  （非公開の一覧が無いので飛ばしました: $PRIVATE_MCP_FILE）"
fi

echo "== マーケットプレイス"
known_marketplaces="$(claude plugin marketplace list 2>/dev/null)"
while read -r mp repo; do
    [ -n "${mp:-}" ] || continue
    if printf '%s\n' "$known_marketplaces" | grep -q "❯ $mp\$"; then
        echo "  ok    ${mp}（追加済み）"
    elif [ "$CHECK" -eq 1 ]; then
        echo "  不足  $mp"
        missing=1
    elif claude plugin marketplace add "$repo" >/dev/null; then
        echo "  追加  $mp"
    else
        echo "  失敗  $mp" >&2
        failed=1
    fi
done <<< "$MARKETPLACES"

if [ "$CHECK" -eq 0 ]; then
    while read -r mp _; do
        [ -n "${mp:-}" ] || continue
        claude plugin marketplace update "$mp" >/dev/null 2>&1 || echo "  更新できませんでした: $mp" >&2
    done <<< "$MARKETPLACES"
fi

echo "== プラグイン"
installed_plugins="$(claude plugin list --json 2>/dev/null | jq -r '.[] | select(.scope == "user") | .id' 2>/dev/null)"
while read -r plugin; do
    [ -n "${plugin:-}" ] || continue
    if printf '%s\n' "$installed_plugins" | grep -qxF "$plugin"; then
        echo "  ok    ${plugin}（導入済み）"
    elif [ "$CHECK" -eq 1 ]; then
        echo "  不足  $plugin"
        missing=1
    elif claude plugin install -s user "$plugin" >/dev/null; then
        echo "  追加  $plugin"
    else
        echo "  失敗  $plugin" >&2
        failed=1
    fi
done <<< "$PLUGINS"

if [ "$CHECK" -eq 1 ]; then
    [ "$missing" -eq 0 ] && echo "足りないものはありません"
    exit "$missing"
fi

echo "== 接続状態（Needs authentication は Claude Code の /mcp で認証する）"
claude mcp list 2>&1 | grep -v '^Checking' | sed -E 's#(https?://[^/ ]+)[^ ]*#\1#' | cut -c1-120

echo
echo "残りの手作業（claude.ai のコネクタ、Chrome）: $DOTFILES_DIR/.claude/account-setup.md"
exit "$failed"
