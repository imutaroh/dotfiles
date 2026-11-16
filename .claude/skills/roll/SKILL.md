---
name: roll
description: Herdr で開いている全タブ・全セッションの状況を 1 つの表にして返すスキル（点呼）。/master で開いた子も、手で開いたタブも同じく並べる。各 Claude の状態（working / blocked / done / idle）、承認待ち、終わった子の「結果:」の行を添える。読むだけで、どのタブにも入力しない。「/roll」「点呼」「いまどんな状況」「全部のタブの様子を見て」「どのセッションが止まってる？」で使用。
---

# roll

Herdr の全タブを点呼して、今の状況を 1 つの表で返す。読むだけのスキルで、どのタブにも文字やキーを送らない。コマンドは herdr-control スキル（`~/.claude/skills/herdr-control/SKILL.md`）と同じもの（`herdr-app` / `hc`）を使う。

## 1. 全タブを並べる

```bash
herdr-app ls | jq -r --arg me "${HC_TERMINAL_ID:-}" '.spaces[] | .name as $s | .tabs[] | .name as $n | .settled as $st | .terminals[] | [$s, ($n // "-"), .terminal, (.app // "-"), (.status // "-"), (if .terminal == $me then "self" else "" end), (if $st then "settled" else "" end)] | @tsv'
```

列は スペース・タブ名・端末・アプリ・状態・この会話か・畳んだタブか。`status` はアプリが報告した値で、普通のシェルは `-` になる。

## 2. 足りない情報を拾う

アプリが `claude-code` の端末について、状態で分けて拾う（`self` はこの会話なので飛ばす）。

| 状態 | 拾うもの |
|---|---|
| `blocked` | `hc get <t> --json` の `status.msg`（何の承認待ちか） |
| `done` / `idle` | `hc read <t> --lines 60` の中で最後に出る「結果:」から始まる 1〜3 行（/master の子が最後に書く行）。無ければ「結果の行なし」 |
| `working` / `error` | 拾わない（working の間は画面が途中のため） |

## 3. 返す

1 つの表にして返す。並べる順は、人の手が要るもの（`blocked`・`error`）→ 終わったもの（`done`・`idle` で「結果:」あり）→ 動いているもの（`working`）→ それ以外。

- `blocked` には「そのタブで承認待ち: <中身>」と添える
- この会話の行は「この会話」と書く
- 端末が 2 つあるタブ（Claude と横のシェルなど）は、Claude の行だけ載せてよい
- 表の後に、人の手が要るタブの名前を 1 行で並べる。無ければ「手が要るタブは無い」

## しないこと

- どのタブにも `hc send` / `hc keys` をしない。承認にも答えない
- タブを開かない・閉じない・畳まない
- 状態を画面の文字から推測しない。`herdr-app ls` と `hc get` の値を使う
