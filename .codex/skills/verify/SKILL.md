---
name: verify
description: "作業が終わったと言う前に、該当するテスト・lint・このリポジトリの確認コマンドを実行し、出力を見せてから完了にする。「/verify」「検証して」「終わったか確認して」「証拠を見せて」で使用。"
---

# verify — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/verify/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。確認コマンドの結果は、実行した出力を見せる。未実行は未実行と書く。
