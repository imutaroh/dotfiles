#!/usr/bin/env bash
# YouTube Data API v3 wrapper for the youtube-research skill (macOS / jq required)
# API key resolution order: $YOUTUBE_API_KEY -> macOS Keychain item "youtube-api-key"
set -euo pipefail

API="https://www.googleapis.com/youtube/v3"

KEY="${YOUTUBE_API_KEY:-$(security find-generic-password -s youtube-api-key -w 2>/dev/null || true)}"
if [ -z "$KEY" ]; then
  echo "ERROR: APIキーが見つかりません。以下のどちらかで設定してください:" >&2
  echo "  1) security add-generic-password -a \"\$USER\" -s youtube-api-key -w 'APIキー' -U" >&2
  echo "  2) export YOUTUBE_API_KEY=APIキー" >&2
  exit 1
fi

call() { # call <endpoint> <curl --data-urlencode args...>
  local endpoint="$1"; shift
  local resp
  resp=$(curl -s --get "$API/$endpoint" "$@" --data-urlencode "key=$KEY")
  if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
    echo "API ERROR ($endpoint): $(echo "$resp" | jq -r '.error.message')" >&2
    exit 1
  fi
  echo "$resp"
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  search)
    # search <query> [maxResults=25] [直近N日 (空=全期間)] [videoDuration: any|short|medium|long]
    # コスト: 100ユニット。出力TSV: videoId, channelTitle, publishedAt, title
    q="$1"; n="${2:-25}"; days="${3:-}"; dur="${4:-any}"
    args=(--data-urlencode "part=snippet" --data-urlencode "q=$q" \
          --data-urlencode "type=video" --data-urlencode "maxResults=$n" \
          --data-urlencode "regionCode=JP" --data-urlencode "relevanceLanguage=ja" \
          --data-urlencode "videoDuration=$dur")
    if [ -n "$days" ]; then
      args+=(--data-urlencode "publishedAfter=$(date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%SZ)")
    fi
    call search "${args[@]}" \
      | jq -r '.items[] | [.id.videoId, .snippet.channelTitle, .snippet.publishedAt, .snippet.title] | @tsv'
    ;;
  stats)
    # stats <videoId,videoId,...>  (最大50件/回)
    # コスト: 1ユニット。出力TSV: videoId, channelId, channelTitle, publishedAt, views, likes, title
    call videos --data-urlencode "part=snippet,statistics" --data-urlencode "id=$1" \
      | jq -r '.items[] | [.id, .snippet.channelId, .snippet.channelTitle, .snippet.publishedAt,
                           (.statistics.viewCount // "0"), (.statistics.likeCount // "0"), .snippet.title] | @tsv'
    ;;
  channels)
    # channels <channelId,channelId,...>  (最大50件/回)
    # コスト: 1ユニット。出力TSV: channelId, subscriberCount, videoCount
    call channels --data-urlencode "part=statistics" --data-urlencode "id=$1" \
      | jq -r '.items[] | [.id, (.statistics.subscriberCount // "0"), (.statistics.videoCount // "0")] | @tsv'
    ;;
  uploads)
    # uploads <channelId> [maxResults=10] : チャンネルの最新投稿一覧（監視用・検索の100倍安い）
    # コスト: 2ユニット。出力TSV: videoId, publishedAt, title
    ch="$1"; n="${2:-10}"
    pl=$(call channels --data-urlencode "part=contentDetails" --data-urlencode "id=$ch" \
      | jq -r '.items[0].contentDetails.relatedPlaylists.uploads')
    call playlistItems --data-urlencode "part=snippet,contentDetails" \
      --data-urlencode "playlistId=$pl" --data-urlencode "maxResults=$n" \
      | jq -r '.items[] | [.contentDetails.videoId, .snippet.publishedAt, .snippet.title] | @tsv'
    ;;
  resolve-channel)
    # resolve-channel <ハンドル名 (@なしでも可)> : @ハンドルからchannelIdを引く
    # コスト: 1ユニット。出力TSV: channelId, channelTitle, subscriberCount
    call channels --data-urlencode "part=snippet,statistics" --data-urlencode "forHandle=$1" \
      | jq -r '.items[] | [.id, .snippet.title, (.statistics.subscriberCount // "0")] | @tsv'
    ;;
  *)
    grep -E '^  # ' "$0" | sed 's/^  # //'
    echo "usage: yt.sh {search|stats|channels|uploads|resolve-channel} ..."
    ;;
esac
