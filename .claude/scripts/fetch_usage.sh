#!/bin/bash
# macOS キーチェーンから Claude Code の OAuth トークンを取得し、
# Anthropic の使用量 API を呼び出して結果を返すスクリプト。
# macOS 専用（security コマンドを使用）。

set -euo pipefail

# キーチェーンからトークン取得
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || {
    echo '{"error": "キーチェーンから認証情報を取得できませんでした。Claude Code で認証済みか確認してください。"}'
    exit 1
}

TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken // empty')
if [ -z "$TOKEN" ]; then
    echo '{"error": "OAuth トークンが見つかりません。Claude Code で再認証してください。"}'
    exit 1
fi

# API 呼び出し。トークンは ps で見えるコマンドライン引数に載せず、標準入力の curl 設定で渡す
RESPONSE=$(curl -s --max-time 5 -K - "https://api.anthropic.com/api/oauth/usage" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Accept: application/json" <<<"header = \"Authorization: Bearer $TOKEN\"")

# レスポンス検証
if ! echo "$RESPONSE" | jq -e '.five_hour' > /dev/null 2>&1; then
    echo '{"error": "API からの応答が不正です。トークンが期限切れの可能性があります。"}'
    exit 1
fi

echo "$RESPONSE"
