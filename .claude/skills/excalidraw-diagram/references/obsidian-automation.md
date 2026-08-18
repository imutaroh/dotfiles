# Obsidian を CLI から操作する

`preview.sh` で足りないこと（設定変更・プラグイン導入・GUI 操作）をするときに読む。

## 環境

- vault: `/Users/imutaakihiro/repos/imutaakihiro/ObsidianImus`（git 管理。obsidian-git が自動コミットする）
- 開いている vault は `~/Library/Application Support/obsidian/obsidian.json` の `vaults` で
  `open: true` のものを見る。vault 名を決め打ちしない
- **UI 言語は日本語**

## ファイルを開く

```bash
open "obsidian://open?vault=<URLエンコードした vault 名>&file=<URLエンコードした vault 相対パス>"
```

`file` は **`.md` を落とす**。`X.excalidraw.md` なら `X.excalidraw` を渡す。

## スクリーンショット（既定では撮らない）

**既定では撮らない。** 撮るには Obsidian を最前面に持ってくる必要があり、利用者が別の作業をしていると
画面を奪う。2026-08-17 に本人から「画面が持っていかれるのは嫌。ズレていたら手動で伝える」との指示。

代わりに `render.js` のレイアウト検査（箱・ラベルの重なり、テキストのはみ出し）で見た目の崩れを
座標計算だけで検出する。これで拾えないのはフォントのフォールバックだけ。

**明示的に「スクショで確認して」と頼まれたときだけ** `scripts/preview.sh` を使う。このスクリプトは
Obsidian が最前面になったことを確認してからでないと撮らない（他アプリの画面を撮る事故を防ぐため。
実際に一度、利用者の別アプリを撮ってしまっている）。

権限（画面収録）は付与済み。`sleep` は使えないので待ちは `osascript -e 'delay 6'`。

## キーボード操作の罠

### 1. キーバインドを推測しない

**`Cmd+R` は「右サイドバー切り替え」に再割り当てされている。リロードは `Cmd+Shift+R`。**
操作前に必ず `.obsidian/hotkeys.json` を読んで実際の割り当てを確認する。推測で送ると
「反映されない」と誤診してハマる。

### 2. 英字のキーストロークは日本語 IME を通って化ける

`System Events` の `keystroke "Create new drawing"` は IME で変換され、コマンドパレットに
意図した文字列が入らない。**クリップボード経由で回避する。**

```bash
pbpaste > /tmp/clip.bak                 # 退避
printf 'Create new drawing' | pbcopy
osascript -e 'tell application "Obsidian" to activate' \
          -e 'delay 1' \
          -e 'tell application "System Events" to keystroke "p" using {command down}' \
          -e 'delay 1.5' \
          -e 'tell application "System Events" to keystroke "v" using {command down}' \
          -e 'delay 2' \
          -e 'tell application "System Events" to key code 36'
pbpaste_restore() { cat /tmp/clip.bak | pbcopy; }   # 復元を忘れない
```

**そもそも GUI 自動化は最後の手段。** 設定変更はファイルを直接書くほうが速く確実で、
失敗も静かに起きない。GUI を 2〜3 回叩いて通らなければ、本人に手でやってもらう。

## プラグイン設定をファイルから変える

`.obsidian/plugins/obsidian-excalidraw-plugin/data.json` を書き換え、**その後 `Cmd+Shift+R` で
リロード**してプラグインに読み直させる。リロード後に値が残っているか必ず確認する
（起動中のプラグインが in-memory の設定で書き戻すことがあるため）。

主要キー:

| キー | 現在値 | 意味 |
|---|---|---|
| `folder` | `Private/Memos` | 新規作成した図の置き場 |
| `libraryFolderPath` | `Excalidraw/Libraries` | 図形ライブラリ（Memos を汚さないよう据え置き） |
| `scriptFolderPath` | `Excalidraw/Scripts` | プラグインのスクリプト置き場（同上） |
| `drawingFilenamePrefix` | `Drawing ` | GUI で新規作成したときのファイル名接頭辞 |

## プラグイン本体の導入

```bash
D=".obsidian/plugins/obsidian-excalidraw-plugin"
mkdir -p "$D"
for f in main.js manifest.json styles.css; do
  curl -sL -o "$D/$f" "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/download/<tag>/$f"
done
```

`.obsidian/community-plugins.json`（有効リスト）に id が入っていればリロードで読み込まれる。

**`.obsidian/plugins/` は gitignore されている。** 導入はマシンローカル限りで、他のマシンで
vault を開いても図は開けない。別マシンでは再導入が要る。
