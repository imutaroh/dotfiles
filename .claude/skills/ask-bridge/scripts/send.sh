#!/bin/bash
# herdr ボット（claude-bridge）の Webhook に調査の依頼を 1 件 POST する。
# 認証情報（BRIDGE_WEBHOOK_URL / BRIDGE_WEBHOOK_KEY）は実行時に ~/.config/bridge/env から読む。
# URL とキーは引数（ps で見える）・標準出力・エラー文のどこにも出さない。curl へは --config で渡す。
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
使い方: send.sh --query <調べたい内容> [--context <補足>] [--turn <1-5>]
               [--status need_info|done|blocked] [--tab <返信先>] [--dry-run]
  --turn    既定 1。5 まで
  --status  既定 need_info
  --tab     既定 $HC_TERMINAL_ID（Herdr の端末のアドレス。hc send の宛先）
  --dry-run 送らずに body の JSON だけを出す。認証情報のファイルは読まない
EOF
    exit 2
}

query="" context="" turn=1 status=need_info tab="${HC_TERMINAL_ID:-}" dry_run=0
while [ $# -gt 0 ]; do
    case "$1" in
        --query|--context|--turn|--status|--tab)
            [ $# -ge 2 ] || usage
            case "$1" in
                --query) query="$2" ;;
                --context) context="$2" ;;
                --turn) turn="$2" ;;
                --status) status="$2" ;;
                --tab) tab="$2" ;;
            esac
            shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage ;;
        *) echo "知らない引数です: $1" >&2; usage ;;
    esac
done

[ -n "$query" ] || { echo "--query が空です" >&2; exit 2; }
[[ "$turn" =~ ^[1-5]$ ]] || { echo "--turn は 1〜5 の整数にしてください（受け取った値: ${turn}）" >&2; exit 2; }
case "$status" in
    need_info|done|blocked) ;;
    *) echo "--status は need_info / done / blocked のどれかにしてください（受け取った値: ${status}）" >&2; exit 2 ;;
esac
[ -n "$tab" ] || { echo "返信先が決まりません。Herdr の外では --tab を渡してください" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq がありません" >&2; exit 1; }

body=$(jq -n \
    --arg query "$query" \
    --arg tab "$tab" \
    --arg context "$context" \
    --argjson turn "$turn" \
    --arg status "$status" \
    '{query: $query, tab: $tab, context: $context, turn: $turn, status: $status}')

if [ "$dry_run" = 1 ]; then
    printf '%s\n' "$body"
    exit 0
fi

env_file="$HOME/.config/bridge/env"
[ -r "$env_file" ] || { echo "認証情報のファイルがありません: ~/.config/bridge/env" >&2; exit 1; }
# 書き方が崩れていると bash のエラー文に値の断片が出るので、stderr は捨てて固定の文言だけを出す。
# macOS の bash 3.2 は if の中でも source 先に set -e を効かせて無言で落ちるので、set +e で囲む
set +e
# shellcheck source=/dev/null
. "$env_file" 2>/dev/null
env_rc=$?
set -e
if [ "$env_rc" -ne 0 ]; then
    echo "認証情報のファイル（~/.config/bridge/env）を読み込めませんでした。書き方を確かめてください" >&2
    exit 1
fi

# 値は出さず、変数名だけで判定する
for name in BRIDGE_WEBHOOK_URL BRIDGE_WEBHOOK_KEY; do
    value="${!name:-}"
    [ -n "$value" ] || { echo "$name が ~/.config/bridge/env にありません" >&2; exit 1; }
    # curl の設定ファイルの "..." を壊す文字（" と \ と改行）を拒む
    case "$value" in
        *'"'*|*'\'*|*$'\n'*) echo "$name に使えない文字（\" / \\ / 改行）が入っています" >&2; exit 1 ;;
    esac
done

# curl の stderr は捨てる（名前解決の失敗などで URL のホストが出るため）。終了コードだけ見る
rc=0
out=$(printf '%s' "$body" | curl --silent \
    --proto '=https' \
    --connect-timeout 5 --max-time 20 \
    --config <(printf 'url = "%s"\nheader = "Authorization: Bearer %s"\n' \
        "$BRIDGE_WEBHOOK_URL" "$BRIDGE_WEBHOOK_KEY") \
    --header 'Content-Type: application/json' \
    --data-binary @- \
    --write-out '\n%{http_code}' 2>/dev/null) || rc=$?

if [ "$rc" -ne 0 ]; then
    case "$rc" in
        1) echo "送信に失敗しました（curl の終了コード 1。https 以外の URL は送らない）" >&2 ;;
        *) echo "送信に失敗しました（curl の終了コード ${rc}）" >&2 ;;
    esac
    exit 1
fi

http_code="${out##*$'\n'}"

# 応答の本文は出さない。ホスト名やパスの一部を含み得て、完全一致の伏せ字では防げないため
echo "HTTP $http_code (turn=$turn status=$status tab=$tab)"
case "$http_code" in
    2??) exit 0 ;;
    *) exit 1 ;;
esac
