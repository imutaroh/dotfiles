---
name: article-visual-planner
description: "記事（Zenn・ブログ・解説文など）を読み、図解・解説画像を「どこに・何の図を・何枚」入れるべきかをベストプラクティス（実務慣行＋学習科学）に基づいて診断し、ChatGPT Images 2.0（gpt-image-2）にそのまま渡せる日本語の画像生成プロンプト一式を出力するスキル。「図解を入れたい」「挿絵プロンプト作って」「この記事に図解を」「どこに画像を入れる」「画像プロンプトまとめて」「記事に図を最適配置して」で使用。生成画像はクリーンなフラットSTYLEで統一し、日本語ラベルは画像内に直接入れる（Image-2.0は日本語描画が高精度）。"
---

# article-visual-planner — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/article-visual-planner/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
