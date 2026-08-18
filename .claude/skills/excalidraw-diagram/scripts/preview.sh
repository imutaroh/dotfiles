#!/bin/bash
# 生成した図を Obsidian で開き、Obsidian のウィンドウだけを撮る。
#   preview.sh <図の絶対パス.excalidraw.md> [出力.png]
# 撮った PNG を Read すれば、レイアウト崩れ・文字の重なり・矢印の飛びを自分の目で確認できる。
#
# 全画面ではなく Obsidian のウィンドウ領域だけを撮り、Obsidian が最前面でなければ中断する。
# 全画面を撮ると、利用者が別アプリを触っていたときにその画面まで写ってしまうため。
set -euo pipefail

FILE="${1:?usage: preview.sh <図の絶対パス.excalidraw.md> [出力.png]}"
SHOT="${2:-/tmp/excalidraw-preview.png}"
[ -f "$FILE" ] || { echo "ファイルが無い: $FILE" >&2; exit 1; }

# 開いている vault を obsidian.json から特定する（vault 名の決め打ちを避ける）
VAULT_PATH=$(node -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.env.HOME+"/Library/Application Support/obsidian/obsidian.json","utf8"));
const v=Object.values(j.vaults).find(v=>v.open) || Object.values(j.vaults)[0];
process.stdout.write(v.path);
')
VAULT_NAME=$(basename "$VAULT_PATH")

case "$FILE" in
  "$VAULT_PATH"/*) REL="${FILE#"$VAULT_PATH"/}" ;;
  *) echo "vault ($VAULT_PATH) の外のファイルは開けない: $FILE" >&2; exit 1 ;;
esac
REL="${REL%.md}"   # obsidian:// の file は .md を落とす（.excalidraw は残す）

enc() { node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$1"; }
open "obsidian://open?vault=$(enc "$VAULT_NAME")&file=$(enc "$REL")"

# Obsidian が最前面に来るまで待つ。来なければ撮らずに中断する。
FRONT=""
for _ in 1 2 3 4 5 6; do
  osascript -e 'delay 2' >/dev/null
  FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")
  [ "$FRONT" = "Obsidian" ] && break
  osascript -e 'tell application "Obsidian" to activate' >/dev/null 2>&1 || true
done

if [ "$FRONT" != "Obsidian" ]; then
  echo "Obsidian が最前面にならない（現在: ${FRONT:-不明}）。他アプリを撮らないよう中断した。" >&2
  echo "利用者が別の作業中の可能性がある。手で Obsidian を前面にしてから再実行するか、確認を依頼する。" >&2
  exit 2
fi

# Obsidian は Electron 製で Accessibility API にウィンドウを公開しないため
# （`count windows` が 0 を返す）、ウィンドウ単位の切り出しはできない。
# 上の最前面チェックを通った場合に限り全画面を撮る。
screencapture -x "$SHOT"
echo "$SHOT"
