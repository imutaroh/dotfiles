---
name: research-to-note
description: "指示を受けて裏取りリサーチを行い、その結果を note の\"大バズ記事\"に近い読みやすいフォーマット（短段落・小見出し頻度・冒頭フック・画像配置間隔）に整形して Private/Memos/ に投入するパイプラインSkill。画像は本文中に機械可読なプレースホルダ（image-slotコメント＋日本語生成プロンプト）で埋め込み、後からAPI連携でURL差し替えできる状態にする。「これリサーチしてnoteドラフトにして」「バズフォーマットでまとめて」「リサーチから記事まで一気に」「調べてnote形式にして」で使用。内蔵リサーチ手順（旧researchスキル継承）・note-studioの文体規約と内蔵の掴み採点（5フックタイプ）を1本に連結するオーケストレータ。"
---

# research-to-note — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/research-to-note/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
