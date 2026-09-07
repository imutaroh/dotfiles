---
name: feedback-slack-formatter
description: "文字起こし（メンターとの1on1・日報フィードバックなどの話し言葉）を渡されたら、相手（メンター）の発言だけを抽出し、Slack 送信用フォーマットに整形するスキル。整形結果は日報と同じ `Private/Journals/YYYY-MM-DD.md` の末尾に追記する。 以下のような状況で使うこと： - 「FBをSlackにして」「フィードバックをSlackフォーマットにして」「これSlackに送る形にして」 - 「日報のFBの文字起こしをまとめて」「1on1の文字起こしをSlack用にして」 - メンター（相手）との会話の文字起こしを渡され、相手の発言だけ拾ってほしいとき - 自分の発言ではなく相手のフィードバックを整理したいとき"
---

# feedback-slack-formatter — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/feedback-slack-formatter/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
