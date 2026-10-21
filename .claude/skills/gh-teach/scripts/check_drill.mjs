#!/usr/bin/env node
// ドリル HTML の Q 配列を検算する。
// 使い方: node check_drill.mjs <drill.html>
// 見るもの: JS の構文 / 必須フィールド / 正答位置の偏り / 選択肢の長さの揃い / 置き忘れのプレースホルダ / 生の不可視文字
import { readFileSync } from "node:fs";
import vm from "node:vm";

const path = process.argv[2];
if (!path) { console.error("usage: node check_drill.mjs <drill.html>"); process.exit(2); }
const html = readFileSync(path, "utf8");
const errors = [];
const warns = [];

const m = html.match(/<script>([\s\S]*?)<\/script>/);
if (!m) { console.error("NG: <script> が見つからない"); process.exit(1); }
try { new vm.Script(m[1]); } catch (e) { errors.push("JS 構文エラー: " + e.message); }

const leftover = html.match(/\{\{[A-Z_]+\}\}|\/\*QUESTIONS\*\//g);
if (leftover) errors.push("プレースホルダが残っている: " + [...new Set(leftover)].join(" "));
if (/[﻿​�]/.test(html)) errors.push("生の不可視文字か置換文字（U+FEFF / U+200B / U+FFFD）が入っている。&#x...; で書く");

let Q = [];
try {
  const qsrc = m[1].match(/const Q = (\[[\s\S]*?\n\]);/);
  Q = vm.runInNewContext(qsrc[1]);
} catch (e) { errors.push("Q 配列を読めない: " + e.message); }

const strip = s => String(s).replace(/<[^>]+>/g, "").replace(/&#x?[0-9a-f]+;/gi, "x");
const counts = [0, 0, 0, 0];
const levels = {};
Q.forEach((q, i) => {
  const id = `Q${i + 1}`;
  for (const k of ["level", "tag", "q", "o", "a", "point", "wrong"]) {
    if (q[k] === undefined || q[k] === "") errors.push(`${id}: ${k} が無い`);
  }
  if (!Array.isArray(q.o) || q.o.length !== 4) { errors.push(`${id}: 選択肢が4つではない`); return; }
  if (!(q.a >= 0 && q.a <= 3)) errors.push(`${id}: a が 0〜3 ではない`);
  counts[q.a] = (counts[q.a] || 0) + 1;
  levels[q.level] = (levels[q.level] || 0) + 1;
  const lens = q.o.map(o => strip(o).length);
  const min = Math.min(...lens), max = Math.max(...lens);
  if (max > min * 1.6 && max - min > 15) warns.push(`${id}: 選択肢の長さがばらつく（${lens.join("/")}字）`);
  if (lens[q.a] === max && max > min * 1.3) warns.push(`${id}: 正答の選択肢が一番長い（${lens.join("/")}字）。長さで当てられる`);
});

const n = Q.length;
if (n) {
  const exp = n / 4;
  counts.forEach((c, k) => {
    if (Math.abs(c - exp) > Math.max(1, exp * 0.5)) warns.push(`正答位置が偏っている: ${"ABCD"[k]} が ${c} 問（${n} 問中）`);
  });
}

console.log(`問題数 ${n} / レベル別 ${JSON.stringify(levels)} / 正答位置 A${counts[0]} B${counts[1]} C${counts[2]} D${counts[3]}`);
warns.forEach(w => console.log("WARN " + w));
errors.forEach(e => console.log("NG   " + e));
if (errors.length) process.exit(1);
console.log(warns.length ? "OK（WARN を直してから公開する）" : "OK");
