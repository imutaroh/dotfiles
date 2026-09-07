---
name: zukai
description: "トピックを 5歳・15歳・35歳向けの3段階で同時に図解する、タブ切り替え付き HTML アーティファクトを生成する。/zukai トピック のほか、「図解して」「絵で教えて」 「仕組みをわかりやすく」「初心者にもわかるように」など、図が主役の段階的な説明が 役立つ場面で使用する。技術トピックに限らず何にでも使える。"
---

# zukai — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/zukai/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

元スキルの artifact-design / artifact-diagramming / Artifact 公開手順を Codex の既存 visualize スキルに置き換える。利用可能スキルを検索して全文を読み、その出力形式で 5歳 / 15歳 / 35歳のタブ式図解を作る。3〜5要素の同じ骨格、各レベル最低2図、5歳にも嘘のない比喩、上位レベルの制約説明を維持する。sticky タブ、トピック別 localStorage（try/catch）、ライト/ダーク対応は出力環境が許す範囲で実装する。visualize がない場合はローカル HTML を成果物として提示する。URL 公開は自動で行わず、ユーザーが公開を依頼した場合のみ Sites 等の既存スキルを読む。
