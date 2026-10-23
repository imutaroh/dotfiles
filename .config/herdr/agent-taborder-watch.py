#!/usr/bin/env python3
"""herdr のタブラベルに表示位置の番号を自動で振り直す常駐ウォッチャ。

各ワークスペース内のタブラベルに表示位置の番号（`prefix+1..9` で
ジャンプする番号と一致）を振り直す。タブを閉じて番号がずれた場合や、
番号なしでタブを作成・リネームした場合でも、次の reapply で正しい番号に補正される。

以前は Agents サイドバーをタブの表示順に並べるカスタムビュー（`agent.view.set`）も
適用していたが、カスタムビューがあるとサイドバーの並べ方トグル（priority / grouped）が
クリックできなくなるため廃止した（2026-10-23）。組み込みの `tab_order` ソートは
herdr 0.9.5 でもタブ作成順のままだが、grouped 表示はタブの表示順に従う。

タブの並び替え・作成・削除などのイベントを購読し、デバウンスしてから
reapply を行う。接続が切れた場合は指数バックオフで再接続し、
再接続のたびに必ず reapply する（切断中に番号がずれている可能性があるため）。
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import socket
import sys
import threading
import time
import uuid

SOCKET_PATH = os.environ.get(
    "HERDR_SOCKET_PATH", os.path.expanduser("~/.config/herdr/herdr.sock")
)
LOG_PATH = os.path.expanduser("~/.config/herdr/agent-taborder.log")
LOG_MAX_BYTES = 1_000_000

DEBOUNCE_SECONDS = 0.3
RECONNECT_DELAYS = (2, 5, 10)

SUBSCRIBE_EVENT_TYPES = (
    "workspace.created",
    "workspace.closed",
    "workspace.moved",
    "tab.created",
    "tab.closed",
    "tab.moved",
    "tab.renamed",
)

# タブラベル先頭の番号プレフィックスを検出する正規表現。
# 例: "6.ob" -> "ob" / "7" -> "" / "6 Go" -> "Go"
# "2026計画" のように数字の直後が区切り文字でないものにはマッチしない（除去しない）。
_NUMBER_PREFIX_RE = re.compile(r"^\d+(?:[ .]\s*|$)")

_debounce_lock = threading.Lock()
_debounce_timer: threading.Timer | None = None


def setup_logging() -> None:
    log_dir = os.path.dirname(LOG_PATH)
    os.makedirs(log_dir, exist_ok=True)
    try:
        if os.path.exists(LOG_PATH) and os.path.getsize(LOG_PATH) > LOG_MAX_BYTES:
            open(LOG_PATH, "w").close()
    except OSError:
        pass
    logging.basicConfig(
        filename=LOG_PATH,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def send_request(method: str, params: dict, timeout: float = 5.0) -> dict:
    """herdr socket に1リクエストだけ送って結果を返す（接続→送信→1行受信→クローズ）。"""
    request = {"id": uuid.uuid4().hex, "method": method, "params": params}
    payload = (json.dumps(request) + "\n").encode("utf-8")

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.settimeout(timeout)
        sock.connect(SOCKET_PATH)
        sock.sendall(payload)
        with sock.makefile("r", encoding="utf-8") as f:
            line = f.readline()
    finally:
        sock.close()

    if not line:
        raise ConnectionError(f"{method}: herdr からの応答が空でした")

    response = json.loads(line)
    error = response.get("error")
    if error:
        raise RuntimeError(f"{method} failed: {error}")
    return response.get("result", {})


def compute_renumbered_label(label: str, position: int) -> str:
    """既存ラベルから先頭の番号プレフィックスを除いた名前部分に、位置番号を振り直す。"""
    match = _NUMBER_PREFIX_RE.match(label)
    name = label[match.end():] if match else label
    name = name.strip()
    return str(position) if not name else f"{position} {name}"


def reapply() -> None:
    """各ワークスペース内のタブラベルに表示位置の番号を振り直す。"""
    workspaces = send_request("workspace.list", {}).get("workspaces", [])

    tab_count = 0
    renamed = 0
    for ws in workspaces:
        tabs = send_request(
            "tab.list", {"workspace_id": ws["workspace_id"]}
        ).get("tabs", [])
        for ws_position, tab in enumerate(tabs, start=1):
            tab_count += 1

            current_label = tab.get("label", "")
            target_label = compute_renumbered_label(current_label, ws_position)
            if target_label != current_label:
                try:
                    send_request(
                        "tab.rename",
                        {"tab_id": tab["tab_id"], "label": target_label},
                    )
                    renamed += 1
                except Exception:
                    logging.exception(
                        "tab.rename に失敗しました (tab_id=%s)", tab["tab_id"]
                    )

    logging.info(
        "reapply 完了: workspaces=%d tabs=%d tabs_renamed=%d",
        len(workspaces),
        tab_count,
        renamed,
    )


def _fire_debounced_reapply() -> None:
    try:
        reapply()
    except Exception:
        logging.exception("デバウンス後の reapply に失敗しました")


def schedule_debounced_reapply() -> None:
    global _debounce_timer
    with _debounce_lock:
        if _debounce_timer is not None:
            _debounce_timer.cancel()
        _debounce_timer = threading.Timer(
            DEBOUNCE_SECONDS, _fire_debounced_reapply
        )
        _debounce_timer.daemon = True
        _debounce_timer.start()


def _run_subscription(backoff_state: list[int]) -> None:
    """購読接続を1本張り、切れるまでイベントを読み続ける。切れたら例外を送出。"""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.settimeout(10.0)
        sock.connect(SOCKET_PATH)

        request = {
            "id": uuid.uuid4().hex,
            "method": "events.subscribe",
            "params": {
                "subscriptions": [
                    {"type": t} for t in SUBSCRIBE_EVENT_TYPES
                ]
            },
        }
        sock.sendall((json.dumps(request) + "\n").encode("utf-8"))

        f = sock.makefile("r", encoding="utf-8")

        ack_line = f.readline()
        if not ack_line:
            raise ConnectionError("events.subscribe の応答がありませんでした")
        ack = json.loads(ack_line)
        if ack.get("error"):
            raise RuntimeError(f"events.subscribe failed: {ack['error']}")

        logging.info("herdr イベント購読を確立しました")
        backoff_state[0] = 0

        # 再接続直後は必ず reapply する（切断中に番号がずれている可能性があるため）
        try:
            reapply()
        except Exception:
            logging.exception("再接続直後の reapply に失敗しました")

        sock.settimeout(None)
        while True:
            line = f.readline()
            if not line:
                raise ConnectionError("herdr イベント購読の接続が切断されました")
            line = line.strip()
            if not line:
                continue
            try:
                json.loads(line)
            except json.JSONDecodeError:
                logging.warning("イベント行の JSON パースに失敗しました: %s", line)
                continue
            schedule_debounced_reapply()
    finally:
        sock.close()


def watch_forever() -> None:
    backoff_state = [0]
    while True:
        try:
            _run_subscription(backoff_state)
        except Exception:
            logging.exception("herdr イベント購読の接続でエラーが発生しました")

        delay = RECONNECT_DELAYS[min(backoff_state[0], len(RECONNECT_DELAYS) - 1)]
        backoff_state[0] += 1
        logging.info("%d秒後に再接続します", delay)
        time.sleep(delay)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="herdr のタブラベルに表示位置の番号を自動で振り直す常駐ウォッチャ"
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="reapply を1回だけ実行して終了する（動作確認・手動リカバリ用）",
    )
    args = parser.parse_args()

    setup_logging()

    if args.once:
        try:
            reapply()
        except Exception as exc:
            logging.exception("--once の reapply に失敗しました")
            print(f"reapply failed: {exc}", file=sys.stderr)
            return 1
        print("reapply succeeded")
        return 0

    logging.info("agent-taborder-watch 起動 (watch mode)")
    while True:
        try:
            watch_forever()
        except Exception:
            # watch_forever() は内部で無限に再接続を試みるためここには通常到達しないが、
            # 想定外の例外でプロセスが落ちないよう外周でも受け止めて継続する。
            logging.exception("watch ループで想定外のエラーが発生しました。再起動します")
            time.sleep(5)


if __name__ == "__main__":
    sys.exit(main())
