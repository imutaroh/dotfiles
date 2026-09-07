---
name: close
description: "セッションを閉じるときに、そのセッション自体を第三者サブエージェントにレビューさせ、「いむたろ様の Claude Code の使い方」を改善するスキル。生のセッションログだけを証拠に、何を指示し・Claude が何をやり・結果どうだったかを検証し、次回そのまま使えるプロンプト書き換え案と、CLAUDE.md / Skill / hooks への改善提案を出す。「/close」「セッション閉じる」「振り返って」「今日のやり取りレビューして」「使い方の改善点ある？」で使用。コードレビューではない（それは /code-review）。"
---

# close — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/close/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

目的は「いむたろの Codex への指示・前提・介入」の改善であり、成果物レビューや後片付けではない。元スキル Step 1 の Claude extractor を、dotfiles の .codex/scripts/extract-session.py に置き換える:
```text
python3 ~/dotfiles/.codex/scripts/extract-session.py --session-id <現在のID> --source <そのIDのCodex JSONL絶対パス> --output <プロジェクト>/.claude/tmp/close/session-<ID>.md
```
現在の会話IDを実行環境の明示的な識別情報で確認し、JSONL の session_meta.id と照合する。更新日時が最新という理由では選ばない。ID不明・不一致・抽出失敗はここで止め、ctx や記憶で代用しない。親が読むのは抽出結果の統計・同一セッションの照合に必要な最小範囲と、引用検証後のレビューだけ。元スキル Step 3〜5 の第三者レビュー→別エージェントによる引用・話者・前後文脈検証→結果提示を維持する。Codex collaboration ツールを使いモデルは設定継承、Claude サイズ別モデル名は無効。200 KB 超では読み切れていない範囲を明示する。レビュー用プロンプトのログ形式・打切り説明は実際の extractor 出力に合わせ、Claude 固定の800文字とは断定しない。
元スキルの出力形式、指示側とエージェント側の責任分離、該当なしを許す基準、検証済み引用を改変しない制約を維持する。Step 6〜7.5 の承認済みルール反映・日報条件・台帳とプロンプト追記の扱いも維持する。台帳とプロンプトは元スキルの同梱正本を使い、Codex のセッションと分かるよう記録する。権限がなく追記できない場合は未反映と報告する。
