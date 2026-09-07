---
name: structured-workflow
description: "リサーチ・計画・実装の3段階で複雑なタスクを構造的に進めるワークフロー。計画段階ではアノテーションサイクル（ユーザーがインラインコメント → Claude が反映を繰り返す）で品質を担保する。「/structured-workflow」「構造的に進めたい」「リサーチしてから計画を立てて」「しっかり調べてから実装して」「段階的に進めたい」で使用。コード開発、設計、ドキュメント作成、調査分析など、あらゆる複雑なタスクに対応。"
---

# structured-workflow — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/structured-workflow/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
