# .claude

Claude Code のユーザーレベル設定。`setup.sh` が項目ごとに `~/.claude/` へシンボリックリンクを張る（`settings.json` だけは例外。後述）。いつ `/verify`、refuter、`/ship` を使うかは「いつ何を使うか（使用例）」。

## ディレクトリ構成

```
.claude/
├── CLAUDE.md               # カスタム指示（Claude Code と Codex で共通。私的な内容を含むので非公開）
├── settings.json           # Claude Code の設定
├── statusline.sh           # ステータスライン
├── statusline-preview.sh   # ステータスラインの実出力をブラウザで確認する
├── design.md               # ステータスラインとテーマの配色リファレンス
├── hooks/
│   ├── play-sound.sh              # 確認要求時・完了時の効果音
│   └── log-session-stop.sh        # Stop の観察ログ（止めない）
├── scripts/
│   └── hc-label-claude-session.sh  # 会話ログの場所を Herdr の端末ラベルに入れる
├── sounds/                 # 通知音（macOS のシステムサウンドへのリンク）
├── themes/                 # カスタムテーマ
├── output-styles/          # 自作の output style
├── rules/                  # このリポジトリ用の局所ルール（paths に合うファイルを触るときだけ読まれる）
├── agents/                 # サブエージェント（ファイル単位でリンク）
│   ├── refuter.md
│   ├── Explore.md
│   ├── dbt-reviewer.md
│   └── log-reader.md
├── skills/                 # カスタムスキル
└── mods/                   # 自作プラグイン（image-view-bytes は常用、ほかは試作）
```

## settings.json

Claude Code の動作設定。主な項目は `permissions`（自動許可と拒否）、`hooks`、`statusLine`、`enabledPlugins`。

**このファイルだけはシンボリックリンクで管理していない。** `claude doctor` などは一時ファイルと rename で書き戻すので、リンクがその時点で実ファイルに置き換わってしまう。

- `setup.sh` は初回だけコピーで配る
- 設定を変えたら、リポジトリ直下の `./sync-settings.sh` で実環境の内容を取り込んでコミットする
- `./sync-settings.sh --check` は差分の有無だけを見る（差分があれば終了コード 1）
- 公開しているので、一部は取り込まず実環境にだけ残す（`autoMode`、auto モードの既定、公式以外のプラグインなど。一覧は `sync-settings.sh` の先頭）。公式以外のプラグインは新しいマシンで入れ直す

## hooks/

`setup.sh` が `~/.claude/hooks/` へ 1 ファイルずつリンクする。フックの登録は `settings.json` の `hooks` に書く。

| ファイル | 役割 |
|----------|------|
| `play-sound.sh` | 確認要求時（`PermissionRequest`）と完了時（`Stop`）の効果音 |
| `log-session-stop.sh` | `Stop` の観察ログ。`~/.claude/state/session-stops.jsonl` に 1 行足す。`async: true` で、会話は止めない。応答本文は残さない |

`PreSkillShellCommand`（matcher は `Bash|PowerShell`）は、スキルやコマンドの読み込み時に走るシェルを `~/.claude/state/skill-shell-commands.jsonl` に 1 行足す。`exit 0` で、止めない。

GitHub の操作（`gh pr merge` などや `gh api` の書き込み）に確認を出すフックや `ask` ルールは置いていない。止めるかどうかは auto モードの分類器が会話を読んで判断する（2026-11-11 に `ask-gh-api-writes.sh` と `gh pr merge/close/ready` の `ask` を外した）。

## agents/

サブエージェント。`setup.sh` が `~/.claude/agents/` へ 1 ファイルずつリンクする（管理外の定義を消さないため、ディレクトリごとにはしない）。

| ファイル | 役割 |
|----------|------|
| `refuter.md` | 主張された結果や修正を、反例と未検証の前提から読み取りだけで確かめる。ファイルは変えない |
| `Explore.md` | 組み込みの Explore を上書きする。読み取りだけでファイルとコードを探す（Haiku） |
| `dbt-reviewer.md` | dbt モデル・SQL・指標の定義を読み取りだけでレビューする（Sonnet） |
| `log-reader.md` | dbt やテストのログを読み、失敗した箇所を報告する（Haiku） |

## skills/

カスタムスキル（`/スキル名` で呼び出せる拡張機能）。作成方法は[公式ドキュメント](https://code.claude.com/docs/en/skills)を、個々の説明は各ディレクトリの `SKILL.md` を参照。

残す基準は「モデルが知り得ない事実（CLI・API・自作テンプレート）を持つか」で、手順を書いただけのスキルは持たない。

| カテゴリ | スキル |
|----------|--------|
| ツール操作（CLI / API の知識） | `herdr-control`, `hview`, `ask-bridge` |
| 自分の決まりへの入口（正本は Obsidian Vault） | `brand` |
| 作業の確認 | `verify` |
| 学び方（対話の進め方の決まり） | `deep-read` |

公式や配布元から入れ直せるスキルは、ここに複製しない。`skill-creator` は claude.ai が同期する版（`anthropic-skills:skill-creator`）か公式プラグインを使い、Codex は標準で持っている。Hunk のスキルは `hunk skill path` で同梱版を取り出せる。

次のものは追跡していない（gitignore 済み）。外部から入るものは、新しいマシンで入れ直す。

| 名前 | 入手先 |
|------|--------|
| `ctx-agent-history-search` | `ctx integrations` |
| `synced/` | claude.ai が同期する。手で消しても次の同期で戻る |
| `agile-data-modeling` | 非公開の個人用スキル |
| `ap` | 非公開の個人用スキル |
| `yomiyasu` | 配布されているスキル（nanaism 作、MIT）。配布元から入れ直す |
| `.trash/` | claude.ai の同期が、外したスキルを退避する場所 |

## mods/

Claude Code のプラグインとして書いたもの。`setup.sh` では配置せず、`settings.json` の `enabledPlugins` にも入れていない。

| 名前 | 使い方 | 説明 |
|------|--------|------|
| `image-view-bytes` | 常用。`settings.json` の `env` にある `CLAUDE_CODE_PLUGIN_DIRS` で読み込む | 貼った画像のサムネイルを入力欄の上に出す。[claude-image-view](https://github.com/jarrodwatts/claude-image-view) を改変し、ファイルのパスではなく画像の中身を端末へ送る。Herdr デスクトップ版のように画像ファイルを読まない端末でも映る |
| `progress-panel` | 試作。読み込まない | `/progress` でプロジェクトの `.claude/tmp/progress.md` を会話の横に表示する |
| `task-panel` | 試作。読み込まない | `/task-panel` でセッションのタスク一覧を会話の横に表示する |

## 予定タスク

`/tasks` に、そのセッションの予定と `/loop` が出る。繰り返しは、セッションが動いているあいだ最大 30 日残る。リポジトリ直下の CLAUDE.md「作業の進め方と確認」にあるとおり、長く回しているセッションの区切りで、止めたはずの予定が残っていないか見る。

## いつ何を使うか（使用例）

「完了」の言い方と、PR に出すまでの使い分け。確認コマンドの正本はリポジトリ直下の CLAUDE.md「作業の進め方と確認」。`/ship` と `/steward` は [公式](https://code.claude.com/docs/en/ship-command)、サブエージェントの呼び方は [公式](https://code.claude.com/docs/en/sub-agents)。

| コマンド | いつ | 自動か手動 |
|----------|------|------------|
| `/verify` | 「完了」と言う前、PR を出す前 | 手動 |
| refuter | 大きめの変更、「できた」「直った」を疑うとき、設計判断のあと | 手動 |
| `/ship` | 変更が終わり、レビューと watch まで任せたいとき | 手動で開始。放置するなら auto モード |
| `/steward` | 開いている PR でレビューが要らないとき。watch が終わったあとの再開 | 手動で開始 |
| `/tasks` | 長く回しているセッションの区切り | 手動で開いて、残りを消す |

### `/verify`

「完了」と言う前と、PR を出す前に頼む。確認コマンドを実行し、出力を見せてから完了にする。失敗したら完了にしない。実行していない確認は、してないと言う。

このリポジトリでは次を実行する。後ろの 2 つはリンク先を見るので `~/dotfiles` で実行する。worktree からだと必ず NG になる。

```bash
./sync-settings.sh --check
python3 setup-codex-skills.py --check
bash .codex/scripts/check-parity.sh --quick
```

シェルを変えたときは `shellcheck` もかける。ほかのリポジトリでは、その CLAUDE.md、README、パッケージのスクリプトに書いてある確認を実行する。書いて無ければ、変えた言語のテストか lint を 1 つ選ぶ。dbt なら `dbt build`。見当たらなければ、見当たらないと言う。

例:

```text
/verify
```

「検証して」「終わったか確認して」「証拠を見せて」でも同じ。

### refuter

大きめの変更のあと、完了報告や「直った」をそのまま信じないとき、設計判断のあとに使う。読み取りだけ（Read、Glob、Grep）で、反例と未検証の前提を探す。ファイルは変えない。コマンドは実行しない。返事は日本語。

名前を言えば、たいてい refuter に渡る。その 1 件を指定するなら、`@` の候補から選ぶか、`@agent-refuter` と書く（この書き方だと、入力中の候補はファイルが出る。送信すれば解決する）。

```text
refuter サブエージェントでこの完了報告を反証して
@"refuter (agent)" この完了報告を反証して
```

このリポジトリの作業ディレクトリでは `.claude/agents/refuter.md` が読まれる。ほかのリポジトリでは、`setup.sh` が `~/.claude/agents/refuter.md` へ張るリンクが要る。一度張れば足りる。

### `/ship` と `/steward`

Claude Code の CLI で、手元のクローンを開いて打つ。クラウドのセッションには無い。Claude Code v2.1.330 以降、GitHub CLI（`gh`）2.63 以降、git 2.38 以降。

- `/ship`: 変更が終わっていて、コミット → push → PR → `/code-review` → watch まで進める。マージは自分でやる
- `/steward`: PR が既に開いていて、レビューは飛ばして watch だけ始める。watch が終わったあとに再開するときもこれ

引数は努力レベルを先頭にする。例: `/ship low <PR番号> +my-lint-bot`

| 引数 | コマンド | すること |
|------|----------|----------|
| `low` `medium` `high` `xhigh` `max` | `/ship` | レビューの努力。既定は `high` |
| PR 番号か URL | `/ship` `/steward` | その PR を対象にする。watch は自分の PR で、そのブランチを checkout していること |
| `+botname` | `/ship` `/steward` | その bot のコメントも読む。watch を再開するときは付け直す |
| `stop` | `/ship` `/steward` | watch を止める |
| `terms` | `/ship` `/steward` | watch 中にできることと制限を出す |

このリポジトリは公開なので、`/ship` は未コミットの変更をコミットしない。先に自分でコミットする。未コミットの扱いは、次の順で最初に当てはまったものだけ。

- そのブランチの PR が既に開いている: 乗せたい分は自分でコミットして push する
- PR がまだ無く、ブランチが既定ブランチ以外で、そのブランチ自身のコミットがある: そのコミットを push して PR を開く。未コミット分は乗らない
- それ以外: 既定ブランチ以外へ自分でコミットしてから、もう一度 `/ship` する

ここでは worktree（`.claude/worktrees/<名前>`）のブランチに先にコミットする。

注意:

- 確認のダイアログは出ない。commit や push の直前に、行末が `Esc to cancel` の表示が出て、何もしなければ数秒で進む
- `/ship` の前に `git status` を見る。PR に入れないファイルは消すか、`git stash push -u -- <ファイル>` で退ける。秘密は中身を自分で見る。`/ship` が弾くのは `.env` のようなファイル名だけで、中のトークンは見ない
- `/verify` の 3 コマンドを、worktree ではなく `~/dotfiles` で通してから `/ship` する
- 確認を待たずに進めてほしいときは auto モード。ほかの権限モードでは、たいていプロンプトで止まる。`bypassPermissions` では watch が始まらない
- auto-merge は有効にしない。有効だと、チェックが通った時点で GitHub がマージすることがある。切るなら `gh pr merge --disable-auto <番号>`。マージは自分でやる
- watch のあいだはセッションを開いたまま前面に置き、ブランチを切り替えない。Esc、`/clear`、ブランチの切り替えで終わる。止めるときは `/ship stop`
- watch は自分の `gh` と `git` の認証で動く。base へマージできる人や、自分のブランチへ push できる人が、自分の認証で手元のプログラムを走らせうる。信頼できる相手のときだけ放置する

### `/tasks`

長く回しているセッションでは、区切りで `/tasks` を開く。そのセッションの予定と `/loop` が出る。繰り返しは、セッションが動いているあいだ最大 30 日残る。止めたはずのものや、期限の切れたものが残っていたら消す。詳しくは上の「予定タスク」。

レビューが終わり、Claude が作業していないあいだは、動いている watch が `/steward --tend` で始まる予定として出る。

### 1日の流れの例

1. worktree で実装する
2. 「完了」の前に `/verify`（確認は `~/dotfiles`）
3. 大きい変更なら、refuter に完了報告を反証させる
4. `git status` を見て、秘密が無いことを確認し、自分でコミットする
5. `/ship` する。マージは自分でやる
6. セッションの区切りで `/tasks` を見て、残った予定を消す

PR が既に開いていてレビューは要らないとき、または watch が終わったあとは、5 の代わりに `/steward`。

## カスタマイズ

- **通知音**: `sounds/` のリンク先を変える。ファイル名は変えない
- **ステータスライン**: `statusline.sh` を編集する。標準入力の JSON を読み、標準出力に表示内容を書くスクリプト
- **コマンド許可**: `settings.json` の `permissions.allow` に `"Bash(コマンド:*)"` の形で足す
- **フック**: `settings.json` の `hooks` にイベントとコマンドを足す（`Stop`、`PermissionRequest`、`PreSkillShellCommand`、`UserPromptSubmit`、`SessionStart` など）
