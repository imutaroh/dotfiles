---
name: kindle-capture
description: Kindle for Mac で開いている本を1冊まるごと自動スクショ→PDF化する全自動フロー。kindle-screenshot-app（Web UI版）をHTTP APIで駆動し、バックグラウンド取り込み（ユーザーはメイン画面で作業継続可）・途中停止の自動検出と復旧・分割PDFの1冊結合まで行う。「本をPDFにして」「Kindleを取り込んで」「1冊まるごとスクショして」「/kindle-capture」で使用。PDF化後の蔵書登録は /book-to-skill に引き継ぐ。
---

# kindle-capture — Kindle 1冊まるごとPDF化

kindle-screenshot-app のサーバを起動し、HTTP API で「開始 → 監視 → 完了検証 → （停止していたら復旧して再開）→ PDF結合」まで自動で行う。

- リポジトリ: `~/repos/imutaakihiro/kindle-screenshot-app`
- 方式: ページ送り = CGEventPostToPid（フォーカスを奪わない）/ スクショ = `screencapture -l <windowID>`（背面でも撮れる）
- スクリプト類はこのスキルの `scripts/` にある（以下 `$SKILLDIR` = このスキルのディレクトリ）

## 0. 前提確認

1. Kindle の検出: `osascript -l JavaScript $SKILLDIR/scripts/windowlist.js`
   - `found:false` → ユーザーに「Kindle で対象の本を開いてください」と依頼して待つ
2. キャプチャ可否: `screencapture -l <windowID> -o -x probe.png` が成功するか
   - 失敗 → ウィンドウが不可視（別 Space・最小化・ロック）。[references/troubleshooting.md](references/troubleshooting.md) の「可視の条件」をユーザーに案内
3. probe.png を Read して**本のページが表示されていること**を確認（ライブラリ画面なら本を開いてもらう）
4. ユーザーに伝える運用条件:
   - 取り込み中は**マウスカーソルを Kindle ウィンドウに乗せない**（キー受付が死ぬ）
   - Kindle の最小化・Space 切替・リサイズをしない。メイン画面での作業は自由
5. 取り込みは**現在表示中のページから**始まる。表紙からやり直したい場合はユーザーに先頭へ戻してもらう（`sendkey.js <pid> 124` を0.4秒間隔で連打して自動で戻してもよい。表紙で余分に押しても無害）

## 1. サーバ起動と開始

```bash
cd ~/repos/imutaakihiro/kindle-screenshot-app
go build -o "$SCRATCH/kindleweb" ./cmd/kindleweb
("$SCRATCH/kindleweb" -port 5099 -out "$PWD/output" > "$SCRATCH/kindleweb.log" 2>&1 &)
sleep 1
curl -s -X POST http://localhost:5099/ui/start \
  --data-urlencode "book_name=<書名>" \
  -d "max_pages=0" -d "pdf_pages_per_file=50" \
  -d "direction=left" -d "auto_delete_png=on" \
  -o /dev/null -w "%{http_code}\n"   # 200 を確認
```

- `direction`: 日本語の本（縦書き・右綴じ）= `left` / 英語の本 = `right`
- ポート 5099 が使用中なら別ポートに変える
- 開始前にマウスを Kindle から遠ざけておく:
  `osascript -l JavaScript -e 'ObjC.import("Cocoa"); $.CGWarpMouseCursorPosition({x:<メイン画面中央x>, y:<メイン画面中央y>}); "ok"'`

## 2. 監視（バックグラウンド）

`run_in_background` の Bash で 5 秒間隔ポーリング。「完了」「エラー」で抜ける:

```bash
for i in $(seq 1 118); do
  s=$(curl -s http://localhost:5099/ui/status | python3 -c "import sys,re; t=sys.stdin.read(); m=re.findall(r'ページ (\d+)', t); print('完了' if '完了' in t else ('エラー' if 'エラー' in t else '実行中'), m[-1] if m else 0)")
  case "$s" in 完了*|エラー*) echo "$s"; break;; esac
  sleep 5
done
```

速度目安は約 1.2 秒/ページ。ログの「ページN保存」は重複判定で後から消える分を含むため、最終数と1〜2ページずれるのは正常。

## 3. 完了検証（必須 — ここを飛ばさない）

「完了」は**本の最後まで行った保証にならない**（キー受付が死ぬと途中でも自動停止する）。必ず検証する:

1. `screencapture -l <windowID> -o -x done_check.png` して Read
2. フッターの「**Nページ中のMページ目・X%**」を読む（表示がなければ `click_rearm.js` 後のキャプチャに出る。[references/troubleshooting.md](references/troubleshooting.md) 参照）
3. **100% なら完了** → Step 5 へ
4. 100% 未満 = 途中停止 → Step 4 の復旧へ

## 4. 途中停止からの復旧

原因と詳細は [references/troubleshooting.md](references/troubleshooting.md)。手順:

1. ユーザーに一言断ってから再アーム（数秒フォーカスを奪うため）:
   `osascript -l JavaScript $SKILLDIR/scripts/click_rearm.js <ウィンドウ中央のグローバルx> <同y>`
   - `ABORT` が返ったら数秒待って再試行
2. キー復活を検証（sendkey → キャプチャ2枚の md5 比較。troubleshooting.md の手順）
3. マウスを Kindle から遠ざけ、Step 1 の `curl` を `book_name=<書名>_続きN` で再実行（現在ページから続きが撮れる。検証で1ページ進んだ分は戻さない）
4. Step 2〜3 を繰り返す（100% になるまで）

## 5. PDF結合と納品

```bash
# 全 part を撮影順に並べて1冊に結合
osascript -l JavaScript $SKILLDIR/scripts/mergepdfs.js \
  <part1.pdf> <part2.pdf> ... "<出力先>/<書名>_完全版.pdf"   # → "ok pages=N"

# 検証: ページ数と先頭ページ
osascript -l JavaScript $SKILLDIR/scripts/pdfinfo.js count "<書名>_完全版.pdf"
osascript -l JavaScript $SKILLDIR/scripts/pdfinfo.js extract "<書名>_完全版.pdf" <一時out.pdf> 0
# 一時out.pdf を Read して表紙を確認（完全版は100MB超で直接 Read できないことがある）
```

サーバを止める（`pkill -f "kindleweb -port 5099"`）。ユーザーへの報告に含める: 完全版のパス・ページ数・読書位置が本の最後まで進んでいること（必要なら戻してもらう）。

## 6. 後続の提案

- 蔵書登録するか確認 → する場合は `/book-to-skill` を起動（分冊 part PDF をそのまま渡せる。各 part は 100MB 未満で Read 可能）
