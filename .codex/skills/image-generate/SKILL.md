---
name: image-generate
description: "画像生成プロンプトを既存 imagegen スキルで実行し、指定された保存先と生成物を検証する。画像生成やプロンプトから画像作成を依頼されたときに使う。"
---

# image-generate — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/image-generate/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

元スキルの codex exec / codex mcp-server 委譲を実行しない。Codex 自身から Codex を再帰起動せず、既存 imagegen スキルを全文読み、現在利用できる画像生成ツールを使う。プロンプト・描いてよい文字・指定保存先を維持し、1枚ずつ生成する。ローカル保存が要求された場合は実際の成果物を保存し、実ファイルのサイズと画像目視を確認してから完了報告する。ツールが表示画像のみを返した場合は保存完了と偽らず制約を示す。生成失敗時はその画像で止める。Git 操作や無関係な配置整理は行わない。
