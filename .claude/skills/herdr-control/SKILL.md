---
name: herdr-control
description: Herdr デスクトップアプリ（herdr-app / hc）のタブ・ペインを Claude が操作するスキル。別タブで Claude を走らせる、タブの状態確認、指示の送信、承認待ちへの応答、タブを閉じる、で使用。「新しいタブで開いて」「別タブで Claude を走らせて」「そのタブの様子を見て」「承認して」「ペインを分割して実行して」「横のペインでログ見せて」「ターミナルに TUI（hunk/yazi 等）を開いて」。窓に出すのは herdr-app、端末の読み書きと待機は hc。旧 TUI 版の herdr pane / herdr tab は使えない。zellij や Ghostty 自体のタブとは別物。
---

# herdr-control

Herdr（デスクトップアプリ）の操作は 2 つの CLI に分かれている。確認した版は herdr-app 0.1.14 / hc 0.1.19（2026-11-09）。

| やりたいこと | 使うもの |
|---|---|
| タブ・ペインを窓に出す／閉じる／畳む | `herdr-app do <コマンド>` |
| 何が開いているか（space・tab・pane・terminal の ID）を引く | `herdr-app ls` |
| 端末の状態を見る・画面を読む・文字やキーを送る・終わりを待つ | `hc get` / `read` / `send` / `keys` / `wait` |

- 実体は `~/.local/bin/herdr-app` と `~/.local/bin/hc`。バックグラウンドジョブの PATH に無いときは先頭で `export PATH="$HOME/.local/bin:$PATH"` を通す
- 旧 TUI 版の `herdr workspace|tab|pane ...` は動かない（`server_not_running`。2026-11-09 に確認）。古い記述を見つけても使わない
- `hc` の `<t>` は端末のアドレス（`t7` のような短い ID）。`herdr-app ls` の `terminal` で分かる。自分の端末は `$HC_TERMINAL_ID` で、pane ID ではない。自分には送らない

## 守ること

- タブ・分割は頼まれたときだけ作る。作ると即座に表示され、ユーザーの画面が切り替わる。動作確認のためだけに試験用のタブを作らない
- 作るタブには必ず `name` を付け、`folder` も明示する（省略すると、今フォーカスしている端末のフォルダになる）
- ID は `herdr-app ls` で引く。推測せず、フォーカス中のものへの暗黙の対象指定にも頼らない。ID は JSON の文字列で渡す
- 自分が作ったタブ・ペイン以外は、閉じない・キーを押さない・文字を送らない。必要になったら、実行前にユーザーへ確認する
- 引数なしの `herdr-app`（窓を開く／前面に出す）と、アプリや core の停止・再起動（`hc server stop|restart` を含む）はしない。Claude の中から Herdr を起動しない（起動した側の環境変数が全端末に漏れ、Claude の会話ログが保存されなくなった。2026-11-02）
- 窓へのキー・クリックの自動操作はしない（公式の禁止事項）。`hc keys` は端末の中へキーを送る機能で、これとは別

## タブを開く

```bash
herdr-app do tab.new '{"name":"fix login","folder":"/path/to/repo","argv":["claude"],"task":"ログインのバグを調べて"}'
```

| 引数 | 内容 |
|---|---|
| `name` | タブ名。省略すると番号で呼ばれるので必ず付ける |
| `space` | 開くスペースの ID（`herdr-app ls`）。省略すると選択中のスペース |
| `folder` | 端末の開始フォルダ |
| `argv` | 起動するプログラム（JSON 配列）。Claude なら `["claude"]` |
| `task` | `argv` のエージェントへの最初のメッセージ |

- 引数は `--name "fix login" --argv '["claude"]'` の形でも渡せる。未知の引数名は失敗し、有効な名前が返る
- 結果は作られた ID の JSON（例 `{"pane":"…","terminal":"…"}`）。失敗は `{"error":…}` と exit 1。返事を読み、`herdr-app ls` で確かめる。返事は端末ができた合図にすぎず、プログラムが正しく動いた保証ではない（2 秒以内に非 0 で終わると、窓にエラーのトーストが出る）
- 最初の依頼は `task` で渡す。起動直後の `hc send` は取りこぼされ得る
- 依頼の本文に `gh api …` のような文字列を書くと、こちらの Bash コマンド文字列に `ask-gh-api-writes.sh` フックが反応して確認が出る（2026-11-09 の実測）。本文は一時ファイルに置き、`--task "$(cat <ファイル>)"` で渡す
- 例「hunk でレビューしたい」: `argv` なしで開いてシェルを出し（`pane.split` では 2026-11-09 に確認済み。`tab.new` では未確認）、出た `terminal` に `hc send <t> "hunk diff --wrap origin/main...HEAD"`。`--wrap` は必ず付ける（長いコメントや日本語行が折り返されず読めなくなる。`~/.config/hunk/config.toml` の `wrap_lines = true` だけでは効かなかった。2026-08-12）。起動確認は `hc read <t>` か `hunk session list`。`argv` に hunk を直接渡す方法は未検証

## 状態を見る・読む

```bash
herdr-app ls                 # space > tab > terminal。各 terminal の app と status も出る
hc get <t> --json            # state（live / finished）と status
hc read <t>                  # 今の画面
hc read <t> --lines 100      # 画面の上に履歴 100 行を足す
```

- `hc get` の `status` はオブジェクトで、`status.state` が `idle` / `working` / `done` / `blocked` / `error`、`status.msg` に今の作業や承認待ちの中身が入る。プログラムが報告した値で、画面の文字から推測しない。普通のシェルは報告しないので `status` は `null`
- `working` / `blocked` / `error` の間は、履歴読みが画面だけを即座に返す（不完全）
- terminal から tab の ID を引く: `herdr-app ls | jq -r --arg t "<t>" '.spaces[].tabs[] | select(any(.terminals[]; .terminal == $t)) | .id'`（pane は `.terminals[].pane`）

## 指示する・待つ

```bash
hc send <t> "<依頼>"                # 貼り付けて Enter
hc send --if idle <t> "<依頼>"      # idle のときだけ送る
hc wait <t> --timeout 120 --json   # 止まる（idle / done / blocked / error / 終了）まで待つ
```

- `hc send` は貼り付け＋Enter。本人が入力中なら一呼吸待つ。nvim などの TUI に `:cmd` を打つ用途には使わない（旧 TUI 版で、貼り付けが nvim のバッファ本文に入った事故がある）。TUI は `hc keys` で操作する
- Claude に送ると `<hc from="t…">…</hc>` の手紙として届き、`/exit` などの組み込みコマンドは実行されない。終わらせるときはタブを閉じる（2026-11-09 の実測）
- 待つのに `sleep` やポーリングは使わない。`hc wait` の既定は 180 秒で、`reason: timeout` は失敗ではなく途中経過なので、もう一度待つ。待つ間は Bash ツールが塞がるので、`--timeout` で区切る
- `hc wait <t> --output TEXT` はプログラム用で、エージェントには使わない。待ち始めたあとに出た出力だけを見る。マッチ文字列は、送ったコマンドのエコー行に一致しないよう、コマンドの文字列に現れない目印にする

## 承認する（blocked のとき）

1. `hc get <t> --json` で `status.state` が `blocked` になる。`status.msg` に `approve Bash: …` のように承認待ちの中身が出る
2. `hc read --lines 0 <t>` で画面を読み、何を許可する場面か確かめる
3. ユーザーが許可した範囲だけ自分で答える。それ以外は、要点を伝えて聞く
4. 答える: 既定の選択肢なら `hc keys <t> enter`、2 番目なら `hc keys <t> down enter`、拒否は `hc keys <t> esc`
5. `hc wait <t>` に戻る

- `hc send --force` で権限ダイアログを迂回しない（公式の禁止事項）
- 確認が出たかは見た目で判断せず、`hc get` の `status.state` か `~/.claude/state/permission-requests.jsonl` で確かめる

## 閉じる

```bash
herdr-app do tab.close --id <tab の id> --confirmed true
herdr-app do pane.close --pane <pane の id>
```

- `--confirmed true` はアプリ側の確認を飛ばす。自分が作ったタブにだけ使う
- 閉じるとタブの中の端末（走っている Claude を含む）も終わる。見返すかもしれないタブは、閉じずに `herdr-app do tab.settle --id <tab の id>` で畳む（動いたまま一覧から消え、そのエージェントが人を必要としたら戻る）
- 作業後は `herdr-app ls` で、作る前から増えたタブ・ペインが残っていないか確かめる

## ペインを分割して実行する

```bash
herdr-app ls                                                            # 自分の $HC_TERMINAL_ID が入るタブの pane ID を引く
herdr-app do pane.split '{"direction":"right","pane":"<pane の id>"}'    # 戻り値の terminal を控える
hc send <terminal> "<コマンド>"                                           # 新しいペインのシェルへ打つ
herdr-app do pane.close '{"pane":"<作った pane の id>"}'                  # 片付け
```

- `direction` は `right` か `down`。`pane` を省略するとフォーカス中のペインを分割するので、必ず明示する
- 新しいペインはログインシェルなので、`.zprofile` の環境変数の防護が効く
- 同じタブで別件の Claude が動いていても、触らない

## `hc run --bg` は使わない

エージェントは `tab.new` の `argv` で起こし、`hc run --bg` は使わない。公式の `hc --skill` は「エージェントは常に `--bg`」と書いているが、それは窓に出さない作業用エージェントの流儀で、この環境では従わない。公式に合わせて直さないこと。理由:

- `--bg` の端末は `herdr.space` ラベルを付けないと窓に出ない（`herdr-app --skill`: unlabeled workers stay hidden）。ユーザーはタブで Claude の進捗を見て回る運用で、見えないエージェントは扱えない
- 起こした端末は起こした側の子になり、親のプログラムが終わると一緒に終わる（`hc run --help` の `--outlive-parent`）
- `hc run claude` は明示コマンドをシェルを通さずに直接起動する（`hc --skill`）。`.zprofile` 冒頭の環境変数の防護（`CLAUDE*` などを消す）は端末の最初のシェルでしか働かないので、直接起動はその外に出る

## 迷ったら一次情報

```bash
herdr-app commands    # 窓のコマンド全部。引数と説明（窓が無くても動く）
herdr-app --skill     # 窓の公式ガイド
hc --help             # hc のコマンド一覧。個別は hc <コマンド> --help
hc --skill            # hc の公式ガイド
```

版が上がったら、ここで引数や挙動を取り直す。この文書の記述と食い違ったら、一次情報を優先してこの文書を直す。

## このスキルを直すとき

- 正本は dotfiles の `.claude/skills/herdr-control/SKILL.md`。`~/.claude/skills` が `~/dotfiles/.claude/skills` へのディレクトリ symlink なので、`~/.claude/skills/herdr-control/SKILL.md` は別のコピーではなく同じファイル
- `.codex/skills/herdr-control/SKILL.md`（Codex 用）は本文を持たず、正本を実行時に読む橋渡し
- 本文を変えたら、`shasum -a 256 .claude/skills/herdr-control/SKILL.md` の値を `.codex/skill-bridge.json` の `source_sha256` に入れる。入れないと `python3 setup-codex-skills.py --check` が `SOURCE_DRIFT` で落ちる。`description` を変えたら、manifest と Codex 側の `description` も同じ文字列にそろえる
- worktree で検証するときは `python3 setup-codex-skills.py --check --target-dir <存在しないパス>` にする（`~/.agents/skills` のリンクが main を指すため、付けないと必ず NG になる）
- worktree で直した内容は、main に入れて `~/dotfiles` を `git pull --ff-only` するまで実環境に効かない
