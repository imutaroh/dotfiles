---
name: herdr-control
description: herdr（ターミナルワークスペースマネージャ、socket API 付き CLI）のタブ・ペインを Claude が操作するスキル。「新しいタブで開いて」「ペインを分割して実行して」「横のペインでログ見せて」「herdr でタブ/ペイン作成」「ターミナルに TUI（hunk/lazygit 等）を開いて」で使用。herdr セッション内のタブ/ペインの話であり、zellij や Ghostty 自体のタブとは別物。バックグラウンドジョブ（シェルがターミナル外）からでも socket API 経由で操作できるのが価値。
---

# herdr-control

herdr は `/opt/homebrew/bin/herdr`。バックグラウンドジョブの PATH に無いことがあるので、コマンドの先頭で毎回これを通す。

```bash
export PATH="/opt/homebrew/bin:$PATH"
```

## 基本フロー

1. `herdr workspace list` で対象リポジトリの workspace_id（`w48` 等）を label から特定する
2. `herdr tab create` または `herdr pane split` で作業場所を作る
3. `herdr pane run` でコマンドを流し込む
4. `herdr pane read` / `herdr pane wait-output` で結果を確認する
5. 一時的に作ったタブ/ペインは `herdr pane close` / `herdr tab close` で片付ける

## ワークスペース解決

```bash
herdr workspace list
```

JSON で `workspace_id` と `label`（リポジトリ名）、`active_tab_id`、`pane_count`、`tab_count`、`focused` が返る。ユーザーの意図したリポジトリ名から workspace_id を引く。`focused: true` のワークスペースがユーザーが今見ている画面。

## タブ・ペイン作成

```bash
herdr tab create --workspace <workspace_id> --cwd <path> --label <名前> --focus|--no-focus
```

結果 JSON の `result.root_pane.pane_id`（`w48:pH` 等）が新規ペインの ID。

```bash
herdr pane split [<pane_id>] --direction right|down --ratio <float> --cwd <path> --focus|--no-focus
```

pane_id を省略すると現在フォーカス中のペインを分割する。明示指定を基本にする。

- 黙って作業用に作るときは `--no-focus`
- ユーザーに見せる目的で作るときは `--focus`

## コマンド実行

```bash
herdr pane run <pane_id> <command>
```

ペインでコマンドを実行する。`herdr pane --help` には出るがまとまった説明が薄いので存在を忘れやすい。

他に:
- `herdr pane send-text <pane_id> <text>` — テキストを流し込む（改行は送られない）
- `herdr pane send-keys <pane_id> <key> [key ...]` — キー送信。`enter` `esc` のようなキー名単位で渡す。文字列全体は送れない
- `herdr agent send-keys` は **Claude/Codex 等のエージェントペイン専用**。普通のシェルペインに使うと `{"error":{"code":"agent_not_found","message":"agent target <pane_id> not found"}}` になる（実測済み）。シェルペインには `pane send-keys` / `pane run` を使う

## 出力確認

```bash
herdr pane read <pane_id> [--source visible|recent|recent-unwrapped] [--lines N]
herdr pane wait-output <pane_id> (--match TEXT | --regex PATTERN) [--timeout MS]
```

**`wait-output` の落とし穴（実測済み）**: `--match` はターミナル行全体への部分文字列マッチで、コマンドのエコー行も対象になる。`--match` の文字列がコマンド自体に含まれていると、実行完了前にエコー行で即マッチしてしまう。

例: `herdr pane run <id> "sleep 1 && echo done-waiting"` の後 `--match done-waiting` で待つと、`sleep 1` の完了を待たず `❯ sleep 1 && echo done-waiting` という入力エコー行に一致して即座に返ってくる。

回避策: マッチ文字列はコマンド文字列に出現しないユニークなマーカーにする。例えば `echo "===DONE_$(date +%s)==="` のような、実行するコマンド文字列自体には現れない目印を使う。

## 片付け・安全ルール

```bash
herdr pane close <pane_id>
herdr tab close <tab_id>
```

- **自分が作ったタブ/ペイン以外は閉じない**。ユーザーの既存タブ（特に稼働中の hunk-review 等）には触れない
- ユーザーの既存タブ/ペインを閉じる必要が生じた場合は、実行前に必ず確認する
- TUI（hunk, lazygit 等）を起動したペインは、ユーザーが使い終わるまで放置。勝手に close しない
- 作業後は `herdr workspace list` で pane_count / tab_count が作業前と一致することを確認する（後片付け漏れの検知）

## 隠しコマンドの再発見（セルフヒール）

`herdr pane --help` に載らない、または載っていても見落としやすいサブコマンドがある。herdr のアップデートで挙動やサブコマンド一覧が変わったら、以下で全リストを取り直す。

```bash
herdr pane
```

引数無しで実行すると、`list / current / get / layout / process-info / neighbor / edges / focus / resize / zoom / read / rename / split / swap / move / close / send-text / send-keys / wait-output / run / report-agent / report-agent-session / release-agent / report-metadata` のフル一覧が usage 形式で出る。`herdr tab` や `herdr workspace` など他のトップレベルコマンドでも同じ手が使える。

## ユースケース例

「hunk でレビューしたい、新しいタブで開いて」への対応フロー:

```bash
herdr workspace list  # polaris の workspace_id (w48) を特定
herdr tab create --workspace w48 --cwd <repo> --label hunk-review --focus
# 結果の root_pane.pane_id を控える
herdr pane run <pane_id> "hunk diff --wrap origin/main...HEAD"
```

hunk 起動時は **`--wrap` を必ず明示する**（長いコメント・日本語行が折り返されず読めなくなる。`~/.config/hunk/config.toml` の `wrap_lines = true` だけでは効かなかった実例あり 2026-08-12）。

TUI 系は起動確認を `herdr pane read` や対象ツール自身のコマンド（例: `hunk session list`）で行う。`wait-output` で待つ場合は上記の落とし穴に注意し、TUI 起動後の固有の文字列（プロンプトやタイトル）をマッチ対象にする。
