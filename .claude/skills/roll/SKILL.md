---
name: roll
description: Herdr で開いている全タブ・全セッションの状況を 1 つの表にして返すスキル（点呼）。/master で開いた子も、手で開いたタブも同じく並べる。各 Claude の状態（working / blocked / done / idle）を出し、止まっているタブは画面を読んで 1 行に要約する。Haiku の別エージェントで走り、読むだけで、どのタブにも入力しない。「/roll」「点呼」「いまどんな状況」「全部のタブの様子を見て」「どのセッションが止まってる？」で使用。
context: fork
agent: general-purpose
model: haiku
background: false
---

# roll

Herdr の全タブを点呼し、今の状況を 1 つの表にして返せ。読むだけの仕事で、どのタブにも文字やキーを送らない。返事は日本語。

コマンドは `herdr-app` と `hc`。PATH に無ければ先に `export PATH="$HOME/.local/bin:$PATH"` を通す。

## 1. 全タブを並べる

```bash
herdr-app ls | jq -r --arg me "${HC_TERMINAL_ID:-}" '.spaces[] | .name as $s | .tabs[] | .name as $n | .settled as $st | .terminals[] | [$s, ($n // "-"), .terminal, (.app // "-"), (.status // "-"), (if .terminal == $me then "self" else "" end), (if $st then "settled" else "" end)] | @tsv'
```

列は スペース・タブ名・端末・アプリ・状態・呼び出した会話か（`self`）・畳んだタブか。`status` はアプリが報告した値で、普通のシェルは `-` になる。

## 2. 止まっているタブだけ要約する

アプリが `claude-code` で、状態が `done` / `idle` / `blocked` の端末だけを読む。`self` は飛ばす。`working` / `error` とシェルは読まない（状態だけ出す）。

- 画面を読む: `hc read <t> --lines 60`
- `blocked` は `hc get <t> --json` の `status.msg` も読む（何の承認待ちか）
- 画面に「結果:」で始まる行があれば（/master の子が最後に書く報告）、それを要約の代わりにそのまま使う
- 無ければ、画面から「何をしていて、どこで止まっているか」を 40 字前後の 1 行に書く。画面に無いことは書かない

## 3. 返す

1 つの Markdown の表（列: タブ名・状態・中身）にする。並べる順は、人の手が要るもの（`blocked`・`error`）→ 止まっているもの（`done`・`idle`）→ 動いているもの（`working`）→ それ以外（シェルなど）。

- `blocked` の中身は「承認待ち: <何の承認か>」
- `self` の行は中身を「この会話」とする
- 端末が 2 つあるタブ（Claude と横のシェルなど）は、Claude の行だけ載せる
- 表の後に、人の手が要るタブの名前を 1 行で並べる。無ければ「手が要るタブは無い」

## しないこと

- `hc send` / `hc keys` をしない。承認にも答えない
- タブを開かない・閉じない・畳まない
- 状態を画面の文字から推測しない。状態は `herdr-app ls` と `hc get` の値を使う
