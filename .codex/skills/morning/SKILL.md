---
name: morning
description: "1日の始まりに実行する朝のブリーフィング・オーケストレータ。「/morning」「おはよう、今日を始めよう」「朝のブリーフィング」「朝のルーティンやって」で使用。 ①昨日の日報の要約とFB確認 ②Claude Code 使用状況（ai-usage-dashboard）②.5 今日のタイムカレンダー（Google Calendar から1時間グリッド） ③昨日のAIログの日報貼り付け（daily-ai-log に委譲）④Todo.md（実行リスト・上限10）の残タスク提示 を1コマンドで実行し、 今日の日報に「## 朝のブリーフィング」として追記するところまで行う（その日の一手を決めるのはご主人様。AI は聞かない）。"
---

# morning — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/morning/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

Private/CLAUDE.md と現在の日報テンプレートを先に確認し、固定記憶で日付や保存場所を決めない。Calendar の接続がない場合は予定なしではなく「取得失敗・未確認」と表示して他の朝の処理を続ける。Chrome は既存 chrome スキルを優先する。Claude usage の集計値を Codex 使用量・費用として表示しない。ctx が壊れている場合は該当ログ集計だけスキップし、理由を残す。port 等の補助コマンドやスクリプトは実ファイルと現在の引数仕様を確認してから実行する。
