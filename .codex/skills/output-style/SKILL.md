---
name: output-style
description: "Codex の出力スタイル（~/.codex/config.toml の developer_instructions）を自作スタイル（15sai 等）や default に切り替える。output-style や文体変更を依頼されたときに使う。Claude 側の settings.json は変更しない。"
---

# output-style — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/output-style/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

元スキルの Claude settings.json 更新手順は実行しない。Codex では `~/dotfiles/.codex/scripts/sync-output-style.py` が正本で、これが `~/.codex/config.toml` のトップレベルキー `developer_instructions`（Codex がモデル入力に注入する指示文字列。Claude の output style に相当）を書き換える永続設定である点が元スキルと異なる（Codex では「会話の文体指定」ではなく永続反映される）。

### 引数なし（`/output-style` 相当）

```bash
python3 ~/dotfiles/.codex/scripts/sync-output-style.py --show
```

現在の `developer_instructions` の設定状況（マーカーコメントと本文先頭3行）と、`~/dotfiles/.claude/output-styles/*.md` から選べるスタイル一覧（ファイル名 stem・frontmatter の name・description）を表で提示する。`default`（未設定に戻す）も選択肢に含める。

### 引数あり（`/output-style <名前>`相当）

```bash
python3 ~/dotfiles/.codex/scripts/sync-output-style.py <名前>
```

`<名前>` はスタイルファイルの stem（例: `15sai`）または frontmatter の `name`（大文字小文字無視）で一致させる。一致するとスクリプトが `~/.codex/config.toml` を一時ファイル経由・tomllib 検証つきで書き換え、`developer_instructions` を永続化する。**反映は新しいセッションから**（この会話自体はスクリプト実行後も旧設定のまま動いているため、同じスタイル効果をこの会話にも当てたい場合は、取得したスタイル本文の要旨をこのターンの応答方針として手動で適用する）ことを必ず案内する。

`default` を渡すと `developer_instructions` とマーカーコメントを削除し、Codex 既定の指示だけに戻す（`python3 ~/dotfiles/.codex/scripts/sync-output-style.py default`）。

### してはいけないこと（元スキルと共通）

- Claude の `~/.claude/settings.json` を書き換えない（Codex 側の永続設定は config.toml の `developer_instructions` のみ）
- `developer_instructions` 以外のキー（`[tui]` の項目や `project_doc_fallback_filenames` 等）を触らない。それらは `apply-codex-config.py` の担当
- スタイル本文に `'''`（TOML の複数行リテラル文字列の終端記号）が含まれる場合、スクリプトは安全側に倒して書き込みを中断する。その場合はエラーメッセージをそのまま報告し、本文の該当箇所の修正を促す
