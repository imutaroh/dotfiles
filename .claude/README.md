# .claude

Claude Code のユーザーレベル設定。`~/.claude/` にシンボリックリンクされる。

## ディレクトリ構成

```
.claude/
├── CLAUDE.md          # カスタム指示
├── settings.json      # Claude Code 設定
├── statusline.sh      # ステータスライン表示スクリプト
├── hooks/             # イベントフック
│   └── anti-sycophancy.sh # 迎合防止リマインダー（UserPromptSubmit）
├── scripts/           # ステータスライン等で使用するスクリプト
│   └── fetch_usage.sh # API 使用量取得（キーチェーンから実行時にトークン取得）
├── sounds/            # 通知音
│   ├── complete.wav   # タスク完了時
│   └── confirm.wav    # 確認要求時
├── themes/            # カスタムテーマ
└── skills/            # カスタムスキル
```

## ファイル説明

### CLAUDE.md

Claude Code へのカスタム指示を記述するファイル。ユーザーの好みや作業ルールを定義する。

### settings.json

Claude Code の動作設定。主な項目：

| 項目 | 説明 |
|------|------|
| `permissions.allow` | 自動許可するコマンド |
| `permissions.deny` | 拒否するコマンド |
| `hooks` | イベント発生時に実行するコマンド |
| `statusLine` | ステータスライン表示の設定 |

### skills/

カスタムスキル（`/スキル名` で呼び出せる拡張機能）。作成方法は[公式ドキュメント](https://code.claude.com/docs/en/skills)を参照。
個々の説明は各ディレクトリの `SKILL.md` の frontmatter に書いてある。カテゴリの目安：

| カテゴリ | 主なスキル |
|----------|-----------|
| 学習・コード理解 | learn / progressive-learning / code-reading / func-anatomy / readable-code-refactor |
| 記事・コンテンツ制作 | note-create / zenn-article / x-thread / instagram-script / article-studio / article-visual-planner / copywriting-frameworks / hook-and-headline / content-repurpose / story-teach / research-to-note / image-generate |
| 文章規範 | japanese-tech-writing / cognitive-rhythm-writing |
| 日報・振り返り | daily-report-formatter / feedback-slack-formatter / month / yoshida-shoin-fb |
| ノート・ナレッジ管理 | technical-note / research / issue-create / task-dashboard |
| 開発ワークフロー | structured-workflow / architect-mode / worktree-parallel / pr-review-fix-coach / hunk-review / dot-help / ctx-agent-history-search |
| メタ（スキル管理） | skill-creator / find-skills |

Anthropic 公式由来: [doc-coauthoring](https://github.com/anthropics/skills/tree/main/skills/doc-coauthoring) / [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator)

## カスタマイズ

### 通知音の変更

`sounds/` 内の `.wav` ファイルを差し替える。ファイル名は維持すること。

### ステータスラインの変更

`statusline.sh` を編集する。スクリプトは標準入力から JSON を受け取り、標準出力に表示内容を出力する。

### コマンド許可の追加

`settings.json` の `permissions.allow` に追加：

```json
"Bash(コマンド:*)"
```

### フックの追加

`settings.json` の `hooks` にイベントとコマンドを追加。利用可能なイベント：

- `Stop` - タスク完了時
- `PermissionRequest` - 確認要求時
- `UserPromptSubmit` - プロンプト送信時
- `SessionStart` - セッション開始時
