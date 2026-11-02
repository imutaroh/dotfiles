#!/usr/bin/env python3
"""Claude Code の会話ログ（JSONL）から、最新の返答の本文を取り出して JSON で出力する。

「最新の返答」= text ブロックを持つ最後のアシスタントメッセージ（message.id が同じ行を連結）。
サブエージェントの発言（isSidechain）と API エラーの疑似メッセージは除く。
ログが無いときは終了コード 3。返答がまだ無いときは {"text": ""} を出力する。
"""
import json
import sys


def latest_reply(lines):
    message_id, texts, timestamp = None, [], None
    for line in lines:
        if '"assistant"' not in line:  # 大きなログを速く読み飛ばす
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") != "assistant" or entry.get("isSidechain") or entry.get("isApiErrorMessage"):
            continue
        message = entry.get("message") or {}
        content = message.get("content")
        if not isinstance(content, list):
            continue
        found = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        found = [t for t in found if t.strip()]
        if not found:
            continue
        if message.get("id") != message_id:
            message_id, texts = message.get("id"), []
        texts += found
        timestamp = entry.get("timestamp")
    return {"id": message_id, "timestamp": timestamp, "text": "\n\n".join(texts)}


def main():
    try:
        with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
            print(json.dumps(latest_reply(f), ensure_ascii=False))
    except FileNotFoundError:
        print(f"no transcript: {sys.argv[1]}", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
