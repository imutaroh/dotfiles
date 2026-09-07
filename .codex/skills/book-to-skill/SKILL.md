---
name: book-to-skill
description: "Kindleスクショから作ったPDF（画像のみ・テキストレイヤーなし）を視覚読解し、蔵書知識貯蔵庫 ~/repos/imutaakihiro/ObsidianImus/Books/ に書籍ノートとして追加するスキル。「本をSkill化して」「この本を本棚に入れて」「PDFをbooksに追加」「蔵書に追加」「/book-to-skill」で使用。分冊ごとにサブエージェントを並列で走らせ、章別ノート→overview/cheatsheet/glossaryを生成し、Vault へのコミットまで行う。"
---

# book-to-skill — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/book-to-skill/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
