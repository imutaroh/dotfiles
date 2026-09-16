---
name: find-skills
description: "Helps users discover and install agent skills. Use this skill when the user asks \"Is there a skill for X?\", \"Find a skill that can...\", \"How do I do X with a skill?\", or wants to extend the agent's capabilities. Also invoked via /find-skills command. 日本語では「〜のSkillある？」「Skillを探して」「Skillをインストールして」でも使う。"
---

# find-skills — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/find-skills/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
