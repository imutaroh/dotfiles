---
name: ask-bridge
description: Herdr のタブで動く Claude Code から、Grok Bot の herdr ボット（claude-bridge Webhook）に調べものを頼むスキル。X・Web・Slack・Notion・Linear・GitHub の一次情報が要るときに依頼を送り、herdr ボットの調査結果は Herdr 経由でこのタブに次の turn として届く。1 件の依頼は最大 5 turn まで。「/ask-bridge 〜」「bridge に聞いて」「bridge で調べて」「一次情報を取ってきて」で使用。
argument-hint: "<調べたい内容>"
---

# ask-bridge

調べものを Grok Bot の herdr ボット（Webhook ルーティン claude-bridge）に頼む。送るのは同じフォルダの `scripts/send.sh` だけで、Webhook を直接 curl しない。herdr ボットは調べた結果を Herdr 経由でこのタブの Claude に送り返す。

## 送る

```bash
~/.claude/skills/ask-bridge/scripts/send.sh \
  --query '<調べたい内容>' \
  --context '<任意の補足。なぜ要るか・既に分かっていること・見てほしい場所>' \
  --turn 1 --status need_info
```

| 引数 | 内容 |
|---|---|
| `--query` | 調べたい内容。何が分かれば終わりかが読める 1〜3 文にする |
| `--context` | 任意。省くと空文字で送る |
| `--turn` | 1〜5。初回は 1 |
| `--status` | `need_info`（調べてほしい）／ `done`（もう要らない。返事は不要）／ `blocked`（受け取った結果では進めず、人の判断が要る） |
| `--tab` | 返信先。既定は `$HC_TERMINAL_ID`（このタブの端末のアドレス）。普段は付けない |
| `--dry-run` | 送らずに body の JSON を出す。送る前に中身を確かめたいとき |

- 出すのは `HTTP <コード> (turn=… status=… tab=…)` の 1 行だけで、herdr ボットの応答本文は出さない。2xx なら終了コード 0、それ以外と送れなかったときは 1、引数の誤りは 2
- 送ったら待たない。`sleep` や `hc wait` で自分の端末を見張らない。返事は手紙として届くので、その間はほかの作業を進めるか、ターンを終える

## 返事を受ける

herdr ボットの返事は `<hc from="…">…</hc>` の手紙として、このタブに届く。中の turn は送った turn + 1。

- 足りれば、結果を使って元の作業に戻る。herdr ボットに区切りを伝えるときは、受け取った turn + 1 で `--status done` を送る
- まだ足りなければ、受け取った turn + 1 で `--status need_info` を送る。`--query` には「何がまだ分からないか」だけを書き、前の turn の繰り返しにしない
- 受け取った結果では進めず、いむたろの判断が要るなら、受け取った turn + 1 で `--status blocked` を送り、いむたろに状況を伝える
- turn 5 で送れるのは `done` か `blocked` だけ（`need_info` を送ると返事が 6 になり、上限を超える）。5 まで来ても足りなければ、分かったことと分からないことを、いむたろに伝えて止まる

## しないこと

- `~/.config/bridge/env` を読まない・表示しない・`source` しない（`send.sh` の中だけで読む）。`BRIDGE_WEBHOOK_URL` / `BRIDGE_WEBHOOK_KEY` を echo しない
- `--query` / `--context` に、パスワード・トークン・キーなどの秘密を入れない
- `--tab` に、自分の端末以外のアドレスを入れない
- 1 つの問いを分割して同時に何件も送らない。1 件ずつ turn を進める
