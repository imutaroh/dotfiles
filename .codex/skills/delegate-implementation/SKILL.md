---
name: delegate-implementation
description: "新規機能や複数ファイルの実装を Codex サブエージェントに委譲し、親が設計・監査・レビューする。軽微な数行修正は除く。"
---

# delegate-implementation — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/delegate-implementation/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

Agent / SendMessage を実際に利用可能な collaboration.spawn_agent / send_message / followup_task に読み替える。モデルは Codex の現在設定を継承し、Claude 専用のモデル名・単価・effort基準を適用しない。親が設計・対象絶対パス・成果物・禁止範囲・検証方法を明記して委譲し、返された差分と検証結果を自ら監査して説明する。既定は1タスクずつ進め、独立性と並列実行の依頼がある場合にのみ並行させる。同じエージェントへ修正を返し、2回の失敗で親が引き取る。サブエージェントは Git 操作をしない。Codex の spawn は作業ディレクトリを自動隔離しないため、同時編集が必要なら worktree-parallel の補足に従って実在する隔離先を親が用意・確認する。
