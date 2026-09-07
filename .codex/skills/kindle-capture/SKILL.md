---
name: kindle-capture
description: "Kindle for Mac で開いている本を1冊まるごと自動スクショ→PDF化する全自動フロー。kindle-screenshot-app（Web UI版）をHTTP APIで駆動し、バックグラウンド取り込み（ユーザーはメイン画面で作業継続可）・途中停止の自動検出と復旧・分割PDFの1冊結合まで行う。「本をPDFにして」「Kindleを取り込んで」「1冊まるごとスクショして」「/kindle-capture」で使用。PDF化後の蔵書登録は /book-to-skill に引き継ぐ。"
---

# kindle-capture — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/kindle-capture/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
