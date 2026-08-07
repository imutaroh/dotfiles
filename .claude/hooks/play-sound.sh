#!/bin/bash
# Claude Code の効果音フック。第1引数に再生するファイルを渡す。
#
# なぜスクリプトに切り出したのか:
#   フックに afplay を直書きしていたところ、音声デバイスを掴んだまま返らない事例が
#   継続的に発生していた。2026-08-07 の /doctor で直近15日を集計したところ、
#   Stop フックが平均 21 秒・最大 85 秒、さらに 3 回はタイムアウト（約17分）まで
#   走り切っていた。wav 本体は 1.4 秒しかない。
#
#   対策は「即座にバックグラウンドへ逃がす」＋「5秒で強制終了する」の2段構え。
#   macOS には timeout(1) が無いため、sleep + kill のウォッチドッグで代用する。

SOUND="$1"

# ファイルが無ければ黙って成功扱い（フックを失敗させない）
[ -n "$SOUND" ] && [ -f "$SOUND" ] || exit 0

(
    afplay "$SOUND" &
    player_pid=$!
    ( sleep 5; kill "$player_pid" 2>/dev/null ) &
    watchdog_pid=$!
    wait "$player_pid" 2>/dev/null
    # 正常終了したらウォッチドッグを片付ける
    kill "$watchdog_pid" 2>/dev/null
) >/dev/null 2>&1 &

exit 0
