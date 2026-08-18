# .excalidraw.md の内部フォーマット

`scripts/render.js` を拡張・修正するときに読む。全て実ファイルを解凍して確認した値。

## ファイルの外枠

```
---
excalidraw-plugin: parsed
tags:
  - excalidraw
---
==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==

# Excalidraw Data

## Text Elements
<テキスト要素の originalText> ^<要素id>
（空行区切りで繰り返し）

%%
## Drawing
```compressed-json
<圧縮ペイロード>
```
%%
```

**`## Text Elements` を必ず出す。** ここが平文で Obsidian の全文検索・omnisearch に乗る。
vault に図を置く最大の利点がこれなので、省略すると図が「検索に出てこない画像」に成り下がる。
`^id` は Obsidian のブロック ID なので、使える文字は `[a-zA-Z0-9-]` のみ（アンダースコアは不可）。

## 圧縮

**`LZString.compressToBase64`**（`lz-string` パッケージ）。`scripts/vendor/lz-string.min.js` に同梱済みで、
npm install は不要。100 文字ごとに改行を入れて ` ```compressed-json ` ブロックに置く。

非圧縮（` ```json ` ブロック）でもプラグインは読めるが、プラグインが保存し直すと圧縮形式に戻るため、
最初から圧縮で書く。

## シーン

```json
{ "type": "excalidraw", "version": 2, "source": "...", "elements": [...], "appState": {...}, "files": {} }
```

`appState` は最小限でよい。プラグインが `restore()` で既定値を埋める。ただし `theme` と
`viewBackgroundColor` は明示する。

## 要素の共通フィールド

`id` `type` `x` `y` `width` `height` `angle` `strokeColor` `backgroundColor` `fillStyle`
`strokeWidth` `strokeStyle` `roughness` `opacity` `groupIds` `frameId` `index` `roundness`
`seed` `version` `versionNonce` `isDeleted` `boundElements` `updated` `link` `locked`

**`index` は fractional index で、配列順に狭義単調増加でなければならない。** アルファベットは
base62（`0-9A-Za-z`）。`a0` `a1` … と振る。壊れていると要素の重なり順が不定になる。

## 種類ごとの追加フィールド

### rectangle

`roundness: { "type": 3 }` で角丸。内包テキストを持つ場合は
`boundElements: [{ "type": "text", "id": "<テキストid>" }]`。
矢印が刺さる場合は `{ "id": "<矢印id>", "type": "arrow" }` も同じ配列に足す。

### text

`text` / `rawText` / `originalText`（3つとも同じ文字列）、`fontSize` `fontFamily`
`textAlign` `verticalAlign` `containerId` `autoResize` `lineHeight` `hasTextLink`。

**日本語は `fontFamily: 4`（Local Font）+ `lineHeight: 1.448`。** これは vault の既存図から取った実測値。
既定の `1`（Excalifont）は日本語グリフを持たずフォールバックするため見た目が崩れる。
`lineHeight` を変えると内包テキストの縦センターがずれる。

箱の中に入れるときは `containerId` に矩形の id を入れ、`verticalAlign: "middle"`。

### arrow

```json
"points": [[0,0],[dx,dy]],
"startBinding": { "elementId": "<from>", "focus": 0, "gap": 6 },
"endBinding":   { "elementId": "<to>",   "focus": 0, "gap": 6 },
"startArrowhead": null, "endArrowhead": "arrow",
"roundness": { "type": 2 }, "elbowed": false, "lastCommittedPoint": null
```

`x` `y` は始点の絶対座標、`points` はそこからの相対。**binding の `elementId` が実在しないと
矢印が宙に浮く**（Obsidian で開くまで気づけないので、`render.js` の検証で必ず弾く）。

矢印にラベルを乗せるときは、テキスト要素の `containerId` に矢印の id を入れ、
矢印側の `boundElements` に `{ "type": "text", "id": ... }` を入れる。

## 文字幅の見積もり

Excalidraw は保存された `width` / `height` をそのまま初期描画に使う。ずれると箱からはみ出す。
`render.js` では CJK を 1.0em、ASCII を 0.55em として概算している。等幅でない実フォントとの
誤差は残るので、**最終的にはスクリーンショットで目視するしかない**。
