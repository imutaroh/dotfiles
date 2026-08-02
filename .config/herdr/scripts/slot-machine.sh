#!/usr/bin/env bash
# herdr サイドバー用: エージェントが working → idle に遷移した瞬間に
# スロットマシン風の演出をペインのメタデータ行（$slot トークン）に流し込む常駐スクリプト。
set -u

SYMBOLS=("7" "♦" "★" "☘" "◇")
COOLDOWN_SEC=30      # 同一 pane への連続演出を抑制する間隔
POLL_INTERVAL=1      # herdr agent list のポーリング間隔（秒）
FRAME_INTERVAL=0.15  # 演出フレームの送信間隔（秒）

# 状態管理用の連想配列
declare -A prev_status   # pane_id -> 直前の agent_status
declare -A last_fx       # pane_id -> 直近に演出を再生した epoch秒
declare -A play_pid       # pane_id -> 演出サブシェルの PID（多重再生防止）
declare -A fx_panes       # 演出を一度でも送った pane_id の集合（終了時クリア用）

# ランダムに1シンボル選ぶ
random_symbol() {
    echo "${SYMBOLS[$((RANDOM % ${#SYMBOLS[@]}))]}"
}

# 指定 pane にトークンを送る（失敗しても無視）
send_frame() {
    local pane_id="$1" text="$2" ttl="$3"
    herdr pane report-metadata "$pane_id" --source slot-machine --token "slot=${text}" --ttl-ms "$ttl" >/dev/null 2>&1
}

# 1 pane 分のスロット演出（バックグラウンドで実行される）
play_slot() {
    local pane_id="$1"
    local left mid right

    # 揃い演出を15%の確率で強制する
    local force_jackpot=0
    if (( RANDOM % 100 < 15 )); then
        force_jackpot=1
    fi

    # 回転中フェーズ: 全リール回転（6フレーム ≒ 0.9秒）
    local i
    for ((i = 0; i < 6; i++)); do
        send_frame "$pane_id" "🎰 [$(random_symbol)][$(random_symbol)][$(random_symbol)]" 4000
        sleep "$FRAME_INTERVAL"
    done

    # 左リール停止、中央・右は回転継続（3フレーム ≒ 0.45秒）
    left="$(random_symbol)"
    for ((i = 0; i < 3; i++)); do
        send_frame "$pane_id" "🎰 [${left}][$(random_symbol)][$(random_symbol)]" 4000
        sleep "$FRAME_INTERVAL"
    done

    # 中央リール停止、右のみ回転継続（2フレーム ≒ 0.3秒）
    if (( force_jackpot )); then
        mid="$left"
    else
        mid="$(random_symbol)"
    fi
    for ((i = 0; i < 2; i++)); do
        send_frame "$pane_id" "🎰 [${left}][${mid}][$(random_symbol)]" 4000
        sleep "$FRAME_INTERVAL"
    done

    # 右リール停止 = 最終出目
    if (( force_jackpot )); then
        right="$left"
    else
        right="$(random_symbol)"
    fi

    if [[ "$left" == "$mid" && "$mid" == "$right" ]]; then
        send_frame "$pane_id" "🎰 [${left}][${mid}][${right}] JACKPOT!!" 6000
    else
        send_frame "$pane_id" "🎰 [${left}][${mid}][${right}]" 4000
    fi
}

# 演出済み pane のトークンをベストエフォートでクリアして終了する
cleanup() {
    local pane_id
    for pane_id in "${!fx_panes[@]}"; do
        herdr pane report-metadata "$pane_id" --source slot-machine --clear-token slot >/dev/null 2>&1
    done
    exit 0
}
trap cleanup SIGINT SIGTERM

while true; do
    agent_list_json="$(herdr agent list 2>/dev/null)"
    if [[ -z "$agent_list_json" ]]; then
        echo "slot-machine: herdr agent list に失敗しました。2秒後に再試行します。" >&2
        sleep 2
        continue
    fi

    # pane_id と agent_status のペアを1行ずつ取り出す（タブ区切り）
    while IFS=$'\t' read -r pane_id agent_status; do
        [[ -z "$pane_id" ]] && continue

        prev="${prev_status[$pane_id]:-}"
        if [[ "$prev" == "working" && "$agent_status" == "idle" ]]; then
            now="$(date +%s)"
            last="${last_fx[$pane_id]:-0}"
            if (( now - last >= COOLDOWN_SEC )); then
                # 同一 pane で演出が多重再生されていないか確認
                pid="${play_pid[$pane_id]:-}"
                if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
                    last_fx[$pane_id]="$now"
                    fx_panes[$pane_id]=1
                    play_slot "$pane_id" &
                    play_pid[$pane_id]=$!
                fi
            fi
        fi
        prev_status[$pane_id]="$agent_status"
    done < <(echo "$agent_list_json" | jq -r '.result.agents[] | [.pane_id, .agent_status] | @tsv')

    sleep "$POLL_INTERVAL"
done
