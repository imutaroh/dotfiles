# .claude

Claude Code のユーザーレベル設定。`~/.claude/` にシンボリックリンクされる（`settings.json` だけは例外。後述）。

## ディレクトリ構成

```
.claude/
├── CLAUDE.md          # カスタム指示
├── settings.json      # Claude Code 設定
├── design.md          # 寒色トーン&マナー（statusline / テーマの配色リファレンス）
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

**このファイルだけは symlink で管理していない。** `claude doctor` などが一時ファイル + rename で書き戻すため、symlink はその時点で実ファイルに置き換わってしまう（2026-07-27 に実際に発生し、以降の変更が dotfiles に入らないまま乖離した）。

- `setup.sh` は**初回のみ**コピーで配布する
- `/config` や `claude doctor` で設定を変えたら、リポジトリ直下の `./sync-settings.sh` で実環境の内容を dotfiles に取り込んでコミットする
- `./sync-settings.sh --check` は差分の有無だけを見る（差分があれば終了コード 1）

### skills/

カスタムスキル（`/スキル名` で呼び出せる拡張機能）。作成方法は[公式ドキュメント](https://code.claude.com/docs/en/skills)を参照。
個々の説明は各ディレクトリの `SKILL.md` の frontmatter に書いてある。カテゴリの目安：

| カテゴリ | 主なスキル |
|----------|-----------|
| 学習・コード理解 | learn / progressive-learning / code-reading / func-anatomy / readable-code-refactor |
| 記事・コンテンツ制作 | note-studio / zenn-studio / article-visual-planner / image-generate / story-teach / research-to-note / doc-coauthoring |
| 文章規範 | japanese-tech-writing / cognitive-rhythm-writing |
| 日報・振り返り | morning / daily-report-formatter / daily-ai-log / feedback-slack-formatter / month / yoshida-shoin-fb |
| ノート・ナレッジ管理 | technical-note / issue-create / task-dashboard / books / strengths-map |
| 開発ワークフロー | structured-workflow / delegate-implementation / worktree-parallel / pr-review-fix-coach / hunk-review / dot-help / ctx-agent-history-search / terminal-browser |
| メタ（スキル管理） | skill-creator / find-skills |

次の2つは**このリポジトリでは追跡していない**（`skills/` 配下に実体があるだけ）:

- `terminal-browser` — インストーラが張る symlink（実体は別ディレクトリ）。再導入はインストーラで行う
- `books` — 著作物の要約を含むため private リポジトリ `imutaroh/book-skills` を clone して配置する

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
