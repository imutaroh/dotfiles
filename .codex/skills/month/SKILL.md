---
name: month
description: "月次振り返りサマリーを生成して Private/Journals/Monthly/YYYY-MM-monthly.md に保存するスキル。 対象月の日報を全読みし、「実務ベース」「学びベース」「辛口指摘（反省の再放送検出）」を出す。 以下のような状況で使うこと： - 「/month」「6月の振り返りをまとめて」「月次サマリー作って」 - 「今月の日報を実務ベース・学びベースで教えて」"
---

# month — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/month/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
