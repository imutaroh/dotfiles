# .claude

Claude Code のユーザーレベル設定。`setup.sh` が項目ごとに `~/.claude/` へシンボリックリンクを張る（`settings.json` だけは例外。後述）。

## ディレクトリ構成

```
.claude/
├── CLAUDE.md               # カスタム指示（Claude Code と Codex で共通）
├── settings.json           # Claude Code の設定
├── statusline.sh           # ステータスライン
├── statusline-preview.sh   # ステータスラインの実出力をブラウザで確認する
├── design.md               # ステータスラインとテーマの配色リファレンス
├── hooks/
│   └── play-sound.sh       # 確認要求時・完了時の効果音
├── scripts/
│   ├── fetch_usage.sh      # API 使用量の取得（キーチェーンから実行時にトークンを読む）
│   └── hc-label-claude-session.sh  # 会話ログの場所を Herdr の端末ラベルに入れる
├── sounds/                 # 通知音（complete.wav / confirm.wav）
├── themes/                 # カスタムテーマ
├── output-styles/          # 自作の output style
├── skills/                 # カスタムスキル
└── mods/                   # 自作プラグインの試作（progress-panel / task-panel）
```

## settings.json

Claude Code の動作設定。主な項目は `permissions`（自動許可と拒否）、`hooks`、`statusLine`、`enabledPlugins`。

**このファイルだけはシンボリックリンクで管理していない。** `claude doctor` などは一時ファイルと rename で書き戻すので、リンクがその時点で実ファイルに置き換わってしまう。

- `setup.sh` は初回だけコピーで配る
- 設定を変えたら、リポジトリ直下の `./sync-settings.sh` で実環境の内容を取り込んでコミットする
- `./sync-settings.sh --check` は差分の有無だけを見る（差分があれば終了コード 1）
- `autoMode` は個人の環境情報を書くので取り込まない。実環境にだけ残る

## skills/

カスタムスキル（`/スキル名` で呼び出せる拡張機能）。作成方法は[公式ドキュメント](https://code.claude.com/docs/en/skills)を、個々の説明は各ディレクトリの `SKILL.md` を参照。

残す基準は「モデルが知り得ない事実（CLI・API・自作テンプレート）を持つか」で、手順を書いただけのスキルは持たない。

| カテゴリ | スキル |
|----------|--------|
| ツール操作（CLI / API の知識） | `herdr-control` / `hunk-review` / `ctx-agent-history-search` / `dot-help` |
| 出力テンプレート | `zukai` |
| Claude Code の設定 | `output-style` |
| メタ（スキル管理） | `skill-creator` / `find-skills` |

`skill-creator` は [Anthropic 公式のスキル](https://github.com/anthropics/skills/tree/main/skills/skill-creator)に由来する。

次のものは追跡していない（gitignore 済み）。外部から入るものは、新しいマシンで入れ直す。

| 名前 | 入手先 |
|------|--------|
| `grill-me` / `grilling` | `npx skills add`。実体は `~/.agents/skills/`。`/find-skills` から入れ直す |
| `terminal-browser` | terminal-browser のインストーラ。実体は `~/.local/share/terminal-browser/` |
| `synced/` | claude.ai が同期する |
| `gh-teach` | 非公開の個人用スキル |

## mods/

Claude Code のプラグインとして書いた試作。`setup.sh` では配置せず、`settings.json` の `enabledPlugins` にも入れていない。

| 名前 | 説明 |
|------|------|
| `progress-panel` | `/progress` でプロジェクトの `.claude/tmp/progress.md` を会話の横に表示する |
| `task-panel` | `/task-panel` でセッションのタスク一覧を会話の横に表示する |

## カスタマイズ

- **通知音**: `sounds/` の `.wav` を差し替える。ファイル名は変えない
- **ステータスライン**: `statusline.sh` を編集する。標準入力の JSON を読み、標準出力に表示内容を書くスクリプト
- **コマンド許可**: `settings.json` の `permissions.allow` に `"Bash(コマンド:*)"` の形で足す
- **フック**: `settings.json` の `hooks` にイベントとコマンドを足す（`Stop`、`PermissionRequest`、`UserPromptSubmit`、`SessionStart` など）
