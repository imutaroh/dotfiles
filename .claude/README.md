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
個々の説明は各ディレクトリの `SKILL.md` の frontmatter に書いてある。

2026-09-16 に棚卸しし、45本 → 10本に絞った。残す基準は「モデルが知り得ない事実（CLI・API・自作テンプレート）を持つか」で、手順だけのスキルは削除した（履歴は git に残る）。カテゴリの目安：

| カテゴリ | スキル |
|----------|--------|
| ツール操作（CLI / API の知識） | herdr-control / hunk-review / ctx-agent-history-search / dot-help |
| 出力テンプレート | zukai |
| Claude Code の設定 | output-style |
| 思考の壁打ち | grilling（`grill-me` は転送エイリアス） |
| メタ（スキル管理） | skill-creator / find-skills |

次の2つは**このリポジトリでは追跡していない**（`skills/` 配下にあるのは `~/.agents/skills/` への symlink）:

- `grill-me` / `grilling` — `npx skills add` で入れた外部スキル。新しいマシンでは `/find-skills` から再導入する

Anthropic 公式由来: [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator)

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
