# YouTube Data API v3 リファレンス（youtube-research 用）

## クォータ

- 無料枠: **10,000 ユニット/日**。太平洋時間 0:00（日本時間 16:00 or 17:00）にリセット
- 消費量はダッシュボードで確認可能: Google Cloud Console → APIとサービス → YouTube Data API v3 → 割り当て

| 操作 | エンドポイント | ユニット | 1回あたり最大件数 |
|---|---|---|---|
| キーワード検索 | search.list | **100** | 50件 |
| 動画統計 | videos.list | 1 | 50件（IDカンマ連結） |
| チャンネル統計 | channels.list | 1 | 50件（IDカンマ連結） |
| チャンネル投稿一覧 | playlistItems.list | 1 | 50件 |

- 典型的なリサーチ1回（検索1＋stats＋channels）= **約102ユニット** → 1日約90回分
- 破綻条件: キーワード数十個の定期自動実行を組むと検索だけで枠が枯れる。その時は
  検索結果のキャッシュ（同キーワードは日1回まで）を設計に入れる

## search.list の主要パラメータ（yt.sh を拡張する時用）

| パラメータ | 値 | 用途 |
|---|---|---|
| `order` | relevance(既定) / date / viewCount / rating | date=新着順、viewCount=再生数順 |
| `publishedAfter` / `publishedBefore` | ISO8601 (`2026-08-01T00:00:00Z`) | 期間絞り込み |
| `videoDuration` | any / short(<4分) / medium(4-20分) / long(>20分) | shorts の除外・限定 |
| `regionCode` / `relevanceLanguage` | JP / ja | 日本向け結果に寄せる |
| `channelId` | UC... | ⚠️ チャンネル内検索になるが100ユニット。新着取得なら uploads(2ユニット)を使う |
| `videoCategoryId` | 数値ID | カテゴリ限定（26=HowTo, 27=Education など） |

## videos.list / channels.list の補足

- `part=snippet,statistics` 以外に `contentDetails`（動画の長さ `duration`、ISO8601形式 PT12M34S）が取れる
- `statistics.commentCount` も取得可能（エンゲージメント分析に使える）
- 登録者数 (`subscriberCount`) は3桁精度に丸められた概数
- チャンネルの uploads プレイリストIDは `contentDetails.relatedPlaylists.uploads`（UC→UUに変わるだけ）

## 既知の落とし穴

- search.list の結果に含まれる統計情報は snippet のみ（再生数なし）。必ず videos.list で二段取得する
- 高評価数 (`likeCount`) は非公開設定の動画では返らない → jq 側で `// "0"` フォールバック済み
- API キーに HTTP リファラ制限を掛けると curl から使えなくなる。制限は「API制限（YouTube Data API v3のみ）」にする
- `maxResults` は最大50。それ以上は `pageToken` でページング（search は1ページごとに100ユニット消費）

## 拡張アイデア（必要になったら実装）

- コメント取得: commentThreads.list（1ユニット）で上位コメントを取り、反応分析に使う
- 急上昇チャート: videos.list に `chart=mostPopular&regionCode=JP`（1ユニット・検索より安い）
- 字幕取得: captions API は OAuth 必須で API キーでは不可。字幕が要る場合は別途設計
