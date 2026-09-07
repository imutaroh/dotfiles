---
name: book-apply
description: "蔵書（Books/）の枠組みを「問い」に変換し、いむたろ様の Vault の実データ（Private/Journals/ の Action・Notes/・Todo.md・Private/Memos/）と突き合わせてギャップ表を作り、本人が答えたものだけを本文にした ai-work ノートを Private/Memos/ に作る棚卸しスキル。「この本を自分に当てて」「本で自分を診て」「◯◯の知見をVaultに活かして」「本と自分のギャップを出して」「棚卸しして」「/book-apply」で使用。本の内容そのものを聞く相談は books、蔵書の追加は book-to-skill の担当（住み分け）。AI は答えを書かない。"
---

# book-apply — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/book-apply/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
