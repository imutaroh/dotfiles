#!/usr/bin/env node
// spec(JSON) から Obsidian Excalidraw ファイル(.excalidraw.md) を生成し、整合性を検証する。
//   node render.js <spec.json> <出力パス.excalidraw.md>
// 座標・矢印バインディングは全て自動計算する（手で書かない）。
'use strict';
const fs = require('fs');
const path = require('path');
const LZ = require(path.join(__dirname, 'vendor/lz-string.min.js'));

// spec の書き間違いはスタックトレースではなく直せるメッセージで返す（DEBUG=1 で従来通り）
process.on('uncaughtException', (e) => {
  console.error(process.env.DEBUG ? e : 'エラー: ' + e.message);
  process.exit(1);
});

const [, , specPath, outPath] = process.argv;
if (!specPath || !outPath) {
  console.error('usage: node render.js <spec.json> <出力パス.excalidraw.md>');
  process.exit(1);
}
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));

// ---- レイアウト定数（spec.layout で上書き可）----
const L = Object.assign(
  { cellW: 250, gapX: 70, rowH: 84, gapY: 74, fontSize: 16 },
  spec.layout || {}
);
const FONT_FAMILY = 4;     // 4 = Local Font。日本語が確実に出る（既定の 1 は避ける）
const LINE_HEIGHT = 1.448; // fontFamily 4 の実測値。ずらすと縦センターが崩れる

const B62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
let idxN = 0;
const nextIndex = () => {
  const i = idxN++;
  if (i >= B62.length * B62.length) throw new Error('要素が多すぎます（3844 上限）');
  // 常に2桁で払い出す（桁数が混在すると 'az' > 'a10' となり辞書順の単調増加が壊れる）
  return 'a' + B62[Math.floor(i / B62.length)] + B62[i % B62.length];
};
const now = Date.now();
let seedN = 1;
const nextSeed = () => (seedN++ * 1103515245 + 12345) % 2147483647;

// 文字幅の概算（CJK=1.0em / ASCII=0.55em）
const isCJK = (ch) => /[　-ヿ一-鿿＀-￯]/.test(ch);
function lineWidth(line, size) {
  let w = 0;
  for (const ch of line) w += isCJK(ch) ? 1.0 : 0.55;
  return w * size;
}
function metrics(label, size) {
  const lines = label.split('\n');
  return {
    width: Math.max(...lines.map((l) => lineWidth(l, size))),
    height: lines.length * size * LINE_HEIGHT,
  };
}

const base = (id, extra) => ({
  id,
  angle: 0,
  strokeColor: '#1e1e1e',
  backgroundColor: 'transparent',
  fillStyle: 'solid',
  strokeWidth: 2,
  strokeStyle: 'solid',
  roughness: 1,
  opacity: 100,
  groupIds: [],
  frameId: null,
  index: nextIndex(),
  roundness: null,
  seed: nextSeed(),
  version: 1,
  versionNonce: nextSeed(),
  isDeleted: false,
  boundElements: null,
  updated: now,
  link: null,
  locked: false,
  ...extra,
});

const elements = [];
const boxes = {};
const labelRects = []; // 単独テキスト・矢印ラベルの外接矩形（重なり検査用）

// ---- ノード（矩形＋内包テキスト）----
for (const n of spec.nodes || []) {
  if (boxes[n.id]) throw new Error(`node id が重複: ${n.id}`);
  const m = metrics(n.label, L.fontSize);
  // 箱はテキストが必ず収まる幅まで自動で広げる（はみ出しという失敗モードを消す）
  const w = Math.max(n.w || L.cellW, m.width + 32);
  const h = Math.max(L.rowH, m.height + 24);
  const x = n.col * (L.cellW + L.gapX);
  const y = n.row * (L.rowH + L.gapY);
  const textId = 't-' + n.id;

  const rect = base(n.id, {
    type: 'rectangle',
    x, y, width: w, height: h,
    backgroundColor: n.bg || 'transparent',
    strokeColor: n.stroke || '#1e1e1e',
    strokeStyle: n.dashed ? 'dashed' : 'solid',
    roundness: { type: 3 },
    boundElements: [{ type: 'text', id: textId }],
  });
  elements.push(rect, base(textId, {
    type: 'text',
    x: x + (w - m.width) / 2,
    y: y + (h - m.height) / 2,
    width: m.width, height: m.height,
    text: n.label, rawText: n.label, originalText: n.label,
    fontSize: L.fontSize, fontFamily: FONT_FAMILY,
    textAlign: 'center', verticalAlign: 'middle',
    containerId: n.id, autoResize: true,
    lineHeight: LINE_HEIGHT, hasTextLink: false,
  }));
  boxes[n.id] = { x, y, w, h, cx: x + w / 2, cy: y + h / 2, el: rect };
}

// ---- 矢印（接続する辺は位置関係から自動決定）----
for (const e of spec.edges || []) {
  const a = boxes[e.from], b = boxes[e.to];
  if (!a) throw new Error(`edge の from が未定義: ${e.from}`);
  if (!b) throw new Error(`edge の to が未定義: ${e.to}`);

  const dx = b.cx - a.cx, dy = b.cy - a.cy;
  let sx, sy, ex, ey;
  if (Math.abs(dy) > Math.abs(dx)) {
    if (dy > 0) { sx = a.cx; sy = a.y + a.h; ex = b.cx; ey = b.y; }
    else        { sx = a.cx; sy = a.y;       ex = b.cx; ey = b.y + b.h; }
  } else {
    if (dx > 0) { sx = a.x + a.w; sy = a.cy; ex = b.x;       ey = b.cy; }
    else        { sx = a.x;       sy = a.cy; ex = b.x + b.w; ey = b.cy; }
  }

  const arrowId = `e-${e.from}-${e.to}`;
  const arrow = base(arrowId, {
    type: 'arrow',
    x: sx, y: sy, width: Math.abs(ex - sx), height: Math.abs(ey - sy),
    roundness: { type: 2 },
    points: [[0, 0], [ex - sx, ey - sy]],
    lastCommittedPoint: null,
    startBinding: { elementId: e.from, focus: 0, gap: 6 },
    endBinding: { elementId: e.to, focus: 0, gap: 6 },
    startArrowhead: e.bidir ? 'arrow' : null,
    endArrowhead: 'arrow',
    elbowed: false,
    strokeColor: e.color || '#1e1e1e',
    strokeStyle: e.dashed ? 'dashed' : 'solid',
  });
  elements.push(arrow);
  for (const nid of [e.from, e.to]) {
    const r = boxes[nid].el;
    r.boundElements = [...(r.boundElements || []), { id: arrowId, type: 'arrow' }];
  }

  if (e.label) {
    const size = L.fontSize - 2;
    const m = metrics(e.label, size);
    const lid = `tl-${e.from}-${e.to}`;
    labelRects.push({
      id: `矢印ラベル "${e.label}" (${e.from}→${e.to})`,
      x: (sx + ex) / 2 - m.width / 2, y: (sy + ey) / 2 - m.height / 2,
      w: m.width, h: m.height,
    });
    elements.push(base(lid, {
      type: 'text',
      x: (sx + ex) / 2 - m.width / 2, y: (sy + ey) / 2 - m.height / 2,
      width: m.width, height: m.height,
      text: e.label, rawText: e.label, originalText: e.label,
      fontSize: size, fontFamily: FONT_FAMILY,
      textAlign: 'center', verticalAlign: 'middle',
      containerId: arrowId, autoResize: true,
      lineHeight: LINE_HEIGHT, hasTextLink: false,
    }));
    arrow.boundElements = [{ type: 'text', id: lid }];
  }
}

// ---- 単独テキスト（タイトル・凡例・注記）----
for (const t of spec.texts || []) {
  const size = t.size || L.fontSize;
  const m = metrics(t.label, size);
  labelRects.push({
    id: `テキスト "${t.id}"`,
    x: t.col * (L.cellW + L.gapX), y: t.row * (L.rowH + L.gapY),
    w: m.width, h: m.height,
  });
  elements.push(base('x-' + t.id, {
    type: 'text',
    x: t.col * (L.cellW + L.gapX), y: t.row * (L.rowH + L.gapY),
    width: m.width, height: m.height,
    text: t.label, rawText: t.label, originalText: t.label,
    fontSize: size, fontFamily: FONT_FAMILY,
    textAlign: 'left', verticalAlign: 'top',
    containerId: null, autoResize: true,
    lineHeight: LINE_HEIGHT, hasTextLink: false,
    strokeColor: t.color || '#1e1e1e',
  }));
}

// ---- 書き出し ----
const scene = {
  type: 'excalidraw',
  version: 2,
  source: 'https://github.com/zsviczian/obsidian-excalidraw-plugin',
  elements,
  appState: {
    theme: 'light',
    viewBackgroundColor: '#ffffff',
    currentItemFontFamily: FONT_FAMILY,
    currentItemFontSize: L.fontSize,
    currentItemStrokeWidth: 2,
    currentItemRoughness: 1,
    currentItemRoundness: 'round',
    gridSize: 20, gridStep: 5, gridModeEnabled: false,
    scrollX: 100, scrollY: 100, zoom: { value: 1 },
  },
  files: {},
};

// Text Elements セクション = Obsidian の検索・リンクに乗る平文。vault に置く最大の利点なので必須。
const textBlocks = elements
  .filter((e) => e.type === 'text')
  .map((e) => `${e.originalText} ^${e.id.replace(/[^a-zA-Z0-9-]/g, '-')}`)
  .join('\n\n');

const payload = LZ.compressToBase64(JSON.stringify(scene)).replace(/(.{100})/g, '$1\n');

const md = `---
excalidraw-plugin: parsed
tags:
  - excalidraw
---
==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==

# Excalidraw Data

## Text Elements
${textBlocks}

%%
## Drawing
\`\`\`compressed-json
${payload}
\`\`\`
%%`;

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, md, 'utf8');

// ---- 往復検証（ここを飛ばさない。壊れた図は Obsidian で開くまで気づけない）----
const back = JSON.parse(LZ.decompressFromBase64(
  fs.readFileSync(outPath, 'utf8').match(/```compressed-json\n([\s\S]*?)\n```/)[1].replace(/\s/g, '')
));
const ids = new Set(back.elements.map((e) => e.id));
const problems = [];
if (ids.size !== back.elements.length) problems.push('id が重複している');
for (const e of back.elements) {
  for (const b of [e.startBinding, e.endBinding]) {
    if (b && !ids.has(b.elementId)) problems.push(`binding 先が無い: ${e.id} -> ${b.elementId}`);
  }
  if (e.containerId && !ids.has(e.containerId)) problems.push(`containerId 先が無い: ${e.id}`);
}
const idx = back.elements.map((e) => e.index);
if (!idx.every((v, i) => i === 0 || v > idx[i - 1])) problems.push('index が単調増加でない');

// ---- レイアウト検査 ----
// 画面を開かずに見た目の崩れを検出する。スクリーンショットの代わりなので飛ばさない。
// 検出できないのはフォントのフォールバック（日本語が豆腐になる類）だけ。
const TOL = 4; // これ以下のかすりは許容
const overlaps = (a, b) =>
  a.x + a.w - TOL > b.x && b.x + b.w - TOL > a.x &&
  a.y + a.h - TOL > b.y && b.y + b.h - TOL > a.y;

const warnings = [];
const boxRects = Object.entries(boxes).map(([id, b]) => ({ id: `ノード "${id}"`, x: b.x, y: b.y, w: b.w, h: b.h }));

for (let i = 0; i < boxRects.length; i++) {
  for (let j = i + 1; j < boxRects.length; j++) {
    if (overlaps(boxRects[i], boxRects[j])) warnings.push(`${boxRects[i].id} と ${boxRects[j].id} が重なっている`);
  }
}
for (const lr of labelRects) {
  for (const br of boxRects) if (overlaps(lr, br)) warnings.push(`${lr.id} が ${br.id} に重なっている`);
}
for (let i = 0; i < labelRects.length; i++) {
  for (let j = i + 1; j < labelRects.length; j++) {
    if (overlaps(labelRects[i], labelRects[j])) warnings.push(`${labelRects[i].id} と ${labelRects[j].id} が重なっている`);
  }
}
// 自動で広げた箱を報告する（隣の列にぶつかる原因になるため）
for (const n of spec.nodes || []) {
  const want = n.w || L.cellW;
  if (boxes[n.id].w > want) {
    warnings.push(`ノード "${n.id}" はテキストが収まらず幅を ${want} → ${Math.round(boxes[n.id].w)} に広げた（label を \\n で折るか layout.cellW を広げると整う）`);
  }
}

const counts = ['rectangle', 'arrow', 'text']
  .map((t) => `${t} ${back.elements.filter((e) => e.type === t).length}`).join(' / ');
console.log(`書き出し: ${outPath}`);
console.log(`要素数: ${back.elements.length}（${counts}）`);
if (problems.length) {
  console.error('検証 NG:\n  - ' + problems.join('\n  - '));
  process.exit(1);
}
console.log('構造検証 OK: 往復・id 重複なし・binding 全解決・index 単調増加');
if (warnings.length) {
  console.log(`レイアウト検査: 要確認 ${warnings.length} 件\n  - ` + warnings.join('\n  - '));
  console.log('  → col / row を小数でずらすか、layout で間隔を広げて解消する');
} else {
  console.log('レイアウト検査 OK: 箱・ラベルの重なりなし、テキストのはみ出しなし');
}
