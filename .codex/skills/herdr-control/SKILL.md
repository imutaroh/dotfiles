---
name: herdr-control
description: "herdr（ターミナルワークスペースマネージャ、socket API 付き CLI）のタブ・ペインを Claude が操作するスキル。「新しいタブで開いて」「ペインを分割して実行して」「横のペインでログ見せて」「herdr でタブ/ペイン作成」「ターミナルに TUI（hunk/lazygit 等）を開いて」で使用。herdr セッション内のタブ/ペインの話であり、zellij や Ghostty 自体のタブとは別物。バックグラウンドジョブ（シェルがターミナル外）からでも socket API 経由で操作できるのが価値。"
---

# herdr-control — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/herdr-control/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
