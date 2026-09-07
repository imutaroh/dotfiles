---
name: output-style
description: "この Codex 会話の文体を Default / Proactive / Explanatory / Learning または自作スタイルに切り替える。output-style や文体変更を依頼されたときに使う。永続設定は変更しない。"
---

# output-style — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/output-style/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

元スキルの Claude settings.json 更新手順は実行しない。Codex ではこの会話の文体指定として扱う。引数なしは会話で明示済みの指定（なければ指定なし）と Default / Proactive / Explanatory / Learning、自作スタイル候補を提示する。引数ありは Default=通常、Proactive=目的に沿う次の作業を主体的に進める、Explanatory=理由と技術背景を説明、Learning=本人が考え実践する余地を残す、として以降の応答へ反映する。自作スタイルは ~/.claude/output-styles/ とプロジェクト内の対応ファイルを読んで文体部分だけ適用する。永続設定や新セッションへの反映を保証しない。
