#!/usr/bin/env bash
# iPhone のアプリを keep.txt（残すアプリのバンドルID一覧）で宣言的に管理する。
#   ./apps.sh list   … インストール済みアプリを「bundle_id<TAB>name」で出力（keep.txt 作成の元ネタ）
#   ./apps.sh plan   … keep.txt に無いアプリ（削除候補）を表示。何も消さない
#   ./apps.sh apply  … plan の内容を確認後、ideviceinstaller uninstall で一括削除
# 前提: brew install libimobiledevice ideviceinstaller / iPhone を USB 接続し「信頼」済み
# 注意: インストール側は自動化できない（App Store 経由のみ）。Apple 純正アプリは対象外。
set -euo pipefail

cd "$(dirname "$0")"
KEEP=keep.txt

require_device() {
  if [[ -z "$(idevice_id -l 2>/dev/null)" ]]; then
    echo "iPhone が見つかりません。USB 接続と「このコンピュータを信頼」を確認してください" >&2
    exit 1
  fi
}

# ideviceinstaller list の出力: 1 行目ヘッダ、以降 bundle_id, "version", "name"
installed() {
  ideviceinstaller list | sed -n 's/^\([^,]*\), "[^"]*", "\(.*\)"$/\1\t\2/p' | sort
}

kept() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$KEEP" | sort
}

plan() {
  join -t $'\t' -v 1 <(installed) <(kept)
}

case "${1:-}" in
  list)
    require_device
    installed
    ;;
  plan)
    require_device
    [[ -f $KEEP ]] || { echo "$KEEP がありません。'./apps.sh list' の出力を元に作成してください" >&2; exit 1; }
    p=$(plan)
    if [[ -z "$p" ]]; then echo "削除候補なし（keep.txt と一致）"; else
      echo "削除候補 $(wc -l <<<"$p" | tr -d ' ') 件:"; echo "$p"; fi
    ;;
  apply)
    require_device
    p=$(plan)
    [[ -n "$p" ]] || { echo "削除候補なし"; exit 0; }
    echo "以下を削除します:"; echo "$p"; echo
    read -r -p "実行しますか? [y/N] " ans
    [[ $ans == y ]] || { echo "中止"; exit 1; }
    while IFS=$'\t' read -r id name; do
      echo "== $name ($id)"
      ideviceinstaller uninstall "$id"
    done <<<"$p"
    ;;
  *)
    sed -n '2,7p' "$0"; exit 1
    ;;
esac
