# .claude

Claude Code のユーザーレベル設定。`setup.sh` が項目ごとに `~/.claude/` へシンボリックリンクを張る（`settings.json` だけは例外。後述）。

## ディレクトリ構成

```
.claude/
├── CLAUDE.md               # カスタム指示（Claude Code と Codex で共通。私的な内容を含むので非公開）
├── settings.json           # Claude Code の設定
├── statusline.sh           # ステータスライン
├── statusline-preview.sh   # ステータスラインの実出力をブラウザで確認する
├── design.md               # ステータスラインとテーマの配色リファレンス
├── hooks/
│   └── play-sound.sh              # 確認要求時・完了時の効果音
├── scripts/
│   └── hc-label-claude-session.sh  # 会話ログの場所を Herdr の端末ラベルに入れる
├── sounds/                 # 通知音（macOS のシステムサウンドへのリンク）
├── themes/                 # カスタムテーマ
├── output-styles/          # 自作の output style
├── rules/                  # このリポジトリ用の局所ルール（paths に合うファイルを触るときだけ読まれる）
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

GitHub の操作（`gh pr merge` などや `gh api` の書き込み）に確認を出すフックや `ask` ルールは置いていない。止めるかどうかは auto モードの分類器が会話を読んで判断する（2026-11-11 に `ask-gh-api-writes.sh` と `gh pr merge/close/ready` の `ask` を外した）。

## skills/

カスタムスキル（`/スキル名` で呼び出せる拡張機能）。作成方法は[公式ドキュメント](https://code.claude.com/docs/en/skills)を、個々の説明は各ディレクトリの `SKILL.md` を参照。

残す基準は「モデルが知り得ない事実（CLI・API・自作テンプレート）を持つか」で、手順を書いただけのスキルは持たない。

| カテゴリ | スキル |
|----------|--------|
| ツール操作（CLI / API の知識） | `herdr-control`, `hview` |

公式や配布元から入れ直せるスキルは、ここに複製しない。`skill-creator` は claude.ai が同期する版（`anthropic-skills:skill-creator`）か公式プラグインを使い、Codex は標準で持っている。Hunk のスキルは `hunk skill path` で同梱版を取り出せる。

次のものは追跡していない（gitignore 済み）。外部から入るものは、新しいマシンで入れ直す。

| 名前 | 入手先 |
|------|--------|
| `ctx-agent-history-search` | `ctx integrations` |
| `synced/` | claude.ai が同期する。手で消しても次の同期で戻る |
| `agile-data-modeling` | 非公開の個人用スキル |
| `ap` | 非公開の個人用スキル |

## mods/

Claude Code のプラグインとして書いたもの。`setup.sh` では配置せず、`settings.json` の `enabledPlugins` にも入れていない。

| 名前 | 使い方 | 説明 |
|------|--------|------|
| `image-view-bytes` | 常用。`settings.json` の `env` にある `CLAUDE_CODE_PLUGIN_DIRS` で読み込む | 貼った画像のサムネイルを入力欄の上に出す。[claude-image-view](https://github.com/jarrodwatts/claude-image-view) を改変し、ファイルのパスではなく画像の中身を端末へ送る。Herdr デスクトップ版のように画像ファイルを読まない端末でも映る |
| `progress-panel` | 試作。読み込まない | `/progress` でプロジェクトの `.claude/tmp/progress.md` を会話の横に表示する |
| `task-panel` | 試作。読み込まない | `/task-panel` でセッションのタスク一覧を会話の横に表示する |

## カスタマイズ

- **通知音**: `sounds/` のリンク先を変える。ファイル名は変えない
- **ステータスライン**: `statusline.sh` を編集する。標準入力の JSON を読み、標準出力に表示内容を書くスクリプト
- **コマンド許可**: `settings.json` の `permissions.allow` に `"Bash(コマンド:*)"` の形で足す
- **フック**: `settings.json` の `hooks` にイベントとコマンドを足す（`Stop`、`PermissionRequest`、`UserPromptSubmit`、`SessionStart` など）
