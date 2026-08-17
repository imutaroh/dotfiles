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

#   2026-08-15 追記: 第1引数にディレクトリを渡せるようにした。
#   ディレクトリのときは中の音声ファイルから1本をランダムに選んで鳴らす。
#   ファイルを渡す従来の使い方はそのまま動く（後方互換）。

TARGET="$1"

[ -n "$TARGET" ] || exit 0

if [ -d "$TARGET" ]; then
    # ディレクトリ直下の音声を集めてランダムに1本選ぶ
    # （macOS に shuf(1) は無いので $RANDOM で添字を引く）
    #
    # find に -L が要る: ~/.claude/sounds/complete.d は dotfiles 実体への
    # シンボリックリンクで、BSD find は -L 無しだとリンクを辿らず候補0件になる。
    # [ -d ] はリンクを辿るため分岐には入り、無音のまま exit 0 して原因が隠れる。
    candidates=()
    while IFS= read -r line; do
        candidates+=("$line")
    done < <(find -L "$TARGET" -maxdepth 1 -type f \
                \( -iname '*.wav' -o -iname '*.aiff' -o -iname '*.aif' \
                   -o -iname '*.mp3' -o -iname '*.m4a' \) \
                ! -name '.*' | sort)

    # 1本も無ければ黙って成功扱い（フックを失敗させない）
    [ "${#candidates[@]}" -gt 0 ] || exit 0

    SOUND="${candidates[RANDOM % ${#candidates[@]}]}"
else
    SOUND="$TARGET"
fi

# ファイルが無ければ黙って成功扱い（フックを失敗させない）
[ -f "$SOUND" ] || exit 0

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
