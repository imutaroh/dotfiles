---
name: pr-review-fix-coach
description: "PRのレビューコメントを取得し、優先度順に整理して、ユーザー自身が1件ずつ修正するのを伴走するコーチングスキル。 「レビューコメント対応したい」「PRの指摘を直したい」「/pr-review-fix-coach」で使用。 自動修正はせず、ユーザーが手を動かすのをガイドする。"
---

# pr-review-fix-coach — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/pr-review-fix-coach/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
