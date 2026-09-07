---
name: youtube-research
description: "YouTube Data API v3 を使って動画リサーチを行い、結果を整形してチャットで報告するスキル。 テーマを渡されたら検索クエリの設計はAIが行う。キーワード検索・伸びている動画の検出 （再生数÷登録者数の伸び率計算）・特定チャンネルの新着監視に対応。 「YouTubeで◯◯を調べて」「YouTubeリサーチして」「YouTubeで情報収集」「伸びてる動画を探して」 「バズってる動画」「チャンネルの新着チェック」「チャンネル監視」で使用。Web検索でのYouTube調査は 再生数・投稿日が取得不可（2026-08-11検証済み）なので、YouTube の数値調査は必ずこのスキルを使う。"
---

# youtube-research — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/youtube-research/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

共通互換規約を適用する。元スキルの目的と成果物の検証条件を保つ。
