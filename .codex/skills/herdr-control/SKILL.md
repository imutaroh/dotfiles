---
name: herdr-control
description: "Herdr デスクトップアプリ（herdr-app / hc）のタブ・ペインを Claude が操作するスキル。別タブで Claude を走らせる、タブの状態確認、指示の送信、承認待ちへの応答、タブを閉じる、で使用。「新しいタブで開いて」「別タブで Claude を走らせて」「そのタブの様子を見て」「承認して」「ペインを分割して実行して」「横のペインでログ見せて」「ターミナルに TUI（hunk/yazi 等）を開いて」。窓に出すのは herdr-app、端末の読み書きと待機は hc。旧 TUI 版の herdr pane / herdr tab は使えない。zellij や Ghostty 自体のタブとは別物。"
---

# herdr-control — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/herdr-control/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
