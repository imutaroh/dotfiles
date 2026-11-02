#!/usr/bin/env python3
"""Print the latest reply from a Claude Code transcript (JSONL) as JSON.

The latest reply is the last assistant message with a text block (lines sharing a message.id are joined).
Subagent messages (isSidechain) and API error pseudo-messages are skipped.
Exits with code 3 when the transcript does not exist. Prints {"text": ""} when there is no reply yet.
"""
import json
import sys


def latest_reply(lines):
    message_id, texts, timestamp = None, [], None
    for line in lines:
        if '"assistant"' not in line:  # Skip through large transcripts quickly
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
