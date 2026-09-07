---
name: readable-code-review
description: "「The Art of Readable Code」(O'Reilly) の15章の観点でコードレビューを行うスキル。バグ探しではなく「読みやすさ」専門のレビューで、本人が自力で気づけていない問題まで15章を網羅的に当てて拾い、指摘リスト（章タグ・該当箇所・改善案・1行の理由）を出すのが目的。承認された指摘だけ適用まで行う。以下のようなリクエストで使用：「リーダブルレビューして」「リーダブルコード観点でレビュー」「読みやすさをレビューして」「命名・コメントをレビューして」「このPR/差分を読みやすさで見て」「/readable-code-review」。バグ・正確性のレビューは /code-review、概念の深掘り解説は learn、コードの読み方訓練は code-reading の担当。Go に限らず全言語対応。"
---

# readable-code-review — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/readable-code-review/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
