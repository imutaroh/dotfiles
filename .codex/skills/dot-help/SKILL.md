---
name: dot-help
description: "ユーザーの dotfiles 全体（Neovim / Ghostty / herdr / karabiner / zellij / zsh / lazygit / starship 等）について「〜するにはどのキー？」「このショートカット何？」「Cmd+◯ って何が起きる？」「この設定どこにある？」といった操作方法・キーバインド・設定の質問に、~/dotfiles と ~/.config の実際の設定を参照して回答する。nvim・ターミナル・シェルのキーバインドや設定に関する質問全般で使用（旧 nvim-help の後継）。どのディレクトリからでも使用可能。調査はサブエージェントに委譲してメインのコンテキストを節約する。"
---

# dot-help — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/dot-help/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
