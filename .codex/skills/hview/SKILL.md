---
name: hview
description: "HTML / Markdown を書いて、Herdr の html-viewer ペイン（hview コマンド）でユーザーに見せるスキル。図・表・比較・設計の説明など、端末の文字より 1 枚のページのほうが分かりやすいものを見せるときに使う。「hview で見せて」「hview で開いて」「HTML で見せて」「ページにして」「図にして見せて」「横に出して」で使用。ビューアはページを画像として映すので、押して開く部品（折りたたみ・タブ・ホバー・リンク）を使わずに書く。claude.ai の Artifact とは別物で、ユーザーが Artifact と言わない限りこちらを使う。"
---

# hview — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/hview/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
