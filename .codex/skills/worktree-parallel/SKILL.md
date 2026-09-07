---
name: worktree-parallel
description: "独立した複数の実装タスクを実在する git worktree に隔離して Codex サブエージェントに委譲し、親がレビュー・統合する。並列実装の依頼に使用。"
---

# worktree-parallel — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/worktree-parallel/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

Claude の isolation: worktree は Codex の spawn 引数ではない。独立性（ファイル・DB・ポート）と並列依頼を確認した親が、git worktree list と現ブランチを live 確認し、.claude/worktrees/ が ignore 対象であることを検証する。必要な作業ブランチと git worktree add により実際の隔離先を作り、各エージェントに絶対パスと作業範囲を渡す。作成や Git 操作は親が通常の Issue・ブランチ規約と権限内で行う。サブエージェントの Git 操作禁止を優先し、コミット・差分監査・統合は親が担当する。自動削除は前提にせず、未統合・未コミットの成果がないと確認できるまで worktree を削除しない。PR 操作は既存の承認規約に従う。隔離先を用意できなければ順次実行に切り替え、並列実行済みと報告しない。
