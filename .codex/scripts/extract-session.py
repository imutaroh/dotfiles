#!/usr/bin/env python3
"""指定した Codex JSONL の可視会話・ツール証拠をローカル Markdown に抽出する。"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import sys


def kind(value):
    return str(value or '').replace('_', '').replace('-', '').lower()


def rendered(value):
    return value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, indent=2)


def message_text(payload):
    content = payload.get('content', payload.get('message', payload.get('text', '')))
    if isinstance(content, str):
        return content, 0
    parts, omitted = [], 0
    if not isinstance(content, list):
        return '', 1 if content else 0
    for part in content:
        if isinstance(part, str):
            parts.append(part)
        elif isinstance(part, dict) and kind(part.get('type')) in ('inputtext', 'outputtext', 'text'):
            parts.append(str(part.get('text', '')))
        else:
            omitted += 1
    return '\n'.join(parts), omitted


def extract(source, session_id):
    lines = source.read_text(encoding='utf-8').splitlines()
    rows, warnings = [], []
    nonempty = [i for i, line in enumerate(lines) if line.strip()]
    last = nonempty[-1] if nonempty else -1
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
            if not isinstance(row, dict):
                raise ValueError(f'L{index+1}: JSON object ではありません')
            rows.append((index+1, row))
        except json.JSONDecodeError as exc:
            if index != last:
                raise ValueError(f'L{index+1}: 中間行の JSON 破損') from exc
            warnings.append(f'L{index+1}: 最終行が不完全なため省略。進行中ログの部分取得です。')
    metadata = [row.get('payload', {}).get('id') for _, row in rows if row.get('type') == 'session_meta']
    if not metadata or any(identity != session_id for identity in metadata):
        raise ValueError('session_meta.id が指定 ID と一致しません（metadata 欠落を含む）')
    primary_messages = set()
    for _, row in rows:
        payload = row.get('payload', {})
        if isinstance(payload, dict) and row.get('type') == 'response_item' and payload.get('type') == 'message':
            if payload.get('role') in ('user', 'assistant') and payload.get('channel') != 'analysis' and payload.get('phase') != 'analysis':
                primary_messages.add((payload['role'], message_text(payload)[0]))
    blocks, unknown = [], Counter()
    attachments, duplicates, excluded = 0, 0, 0
    administrative = {'session_meta', 'turn_context', 'compacted'}
    known_events = {'token_count', 'task_started', 'task_complete', 'turn_aborted', 'context_compacted', 'agent_reasoning', 'agent_reasoning_raw_content'}

    def block(line, label, value):
        blocks.append(f'## L{line} {label}\n\n{value}\n')

    def fields(item, names):
        detail, output_seen = [], {}
        for field in names:
            if field not in item:
                continue
            value = rendered(item[field])
            if field in ('stdout', 'stderr', 'aggregated_output', 'formatted_output'):
                if value in output_seen:
                    detail.append(f'### {field}\n\n（{output_seen[value]} と完全一致のため本文重複を省略）')
                    continue
                output_seen[value] = field
            detail.append(f'### {field}\n\n{value}')
        return '\n\n'.join(detail)

    for line, row in rows:
        rowtype, payload = row.get('type'), row.get('payload', {})
        if rowtype in administrative:
            continue
        if not isinstance(payload, dict):
            unknown[f'{rowtype}:non-object'] += 1
            continue
        subtype = payload.get('type', '')
        normalized = kind(subtype)
        if rowtype == 'response_item':
            if normalized == 'message':
                role = payload.get('role')
                if role not in ('user', 'assistant') or payload.get('channel') == 'analysis' or payload.get('phase') == 'analysis':
                    excluded += 1
                    continue
                body, count = message_text(payload)
                attachments += count
                if body:
                    block(line, role, body)
                if count:
                    block(line, '添付省略', f'非テキスト添付 {count} 件')
            elif normalized == 'agentmessage':
                if payload.get('channel') == 'analysis' or payload.get('phase') == 'analysis':
                    excluded += 1
                    continue
                body, count = message_text(payload)
                attachments += count
                if body:
                    block(line, f'AGENT {payload.get("author", "")} → {payload.get("recipient", "")}', body)
            elif normalized in ('functioncall', 'customtoolcall'):
                block(line, f'TOOL {payload.get("name", "unknown")} call_id={payload.get("call_id", "")}', rendered(payload.get('arguments', payload.get('input', ''))))
            elif normalized in ('functioncalloutput', 'customtoolcalloutput'):
                block(line, f'RESULT call_id={payload.get("call_id", "")}', rendered(payload.get('output', '')))
            elif normalized in ('reasoning', 'analysis'):
                excluded += 1
            else:
                unknown[f'{rowtype}/{subtype}'] += 1
        elif rowtype == 'event_msg':
            if normalized == 'itemcompleted':
                item = payload.get('item', {})
                if not isinstance(item, dict):
                    unknown['event_msg/item_completed/non-object'] += 1
                    continue
                itemtype = kind(item.get('type'))
                if itemtype == 'commandexecution':
                    block(line, f'COMMAND id={item.get("id", "")}', fields(item, ('command', 'cwd', 'status', 'exit_code', 'stdout', 'stderr', 'aggregated_output', 'formatted_output')))
                elif itemtype == 'filechange':
                    block(line, f'FILE CHANGE id={item.get("id", "")}', fields(item, ('changes', 'status', 'stdout', 'stderr')))
                elif itemtype == 'extension':
                    block(line, f'EXTENSION id={item.get("id", "")}', fields(item, ('action', 'kind', 'query', 'results')))
                elif itemtype == 'subagentactivity':
                    excluded += 1
                elif itemtype in ('usermessage', 'agentmessage'):
                    if item.get('phase') == 'analysis' or item.get('channel') == 'analysis':
                        excluded += 1
                        continue
                    role = 'user' if itemtype == 'usermessage' else 'assistant'
                    body, count = message_text(item)
                    if (role, body) in primary_messages:
                        duplicates += 1
                    elif body:
                        block(line, role, body)
                    attachments += count
                elif itemtype in ('reasoning', 'analysis'):
                    excluded += 1
                else:
                    unknown[f'event_msg/item_completed/{item.get("type", "")}'] += 1
            elif normalized in ('usermessage', 'agentmessage'):
                if payload.get('phase') == 'analysis' or payload.get('channel') == 'analysis':
                    excluded += 1
                    continue
                role = 'user' if normalized == 'usermessage' else 'assistant'
                body, count = message_text(payload)
                if (role, body) in primary_messages:
                    duplicates += 1
                elif body:
                    block(line, role, body)
                attachments += count
            elif subtype in known_events or normalized in ('reasoning', 'analysis'):
                excluded += 1
            else:
                unknown[f'{rowtype}/{subtype}'] += 1
        else:
            unknown[str(rowtype)] += 1
    preamble = [f'# Codex セッション {session_id}', '', 'ローカルレビュー専用。秘密情報を含み得るため、原本・抽出結果を外部公開しない。', 'L番号は元JSONLの行番号。発言・ツール本文は文字数で打ち切っていない。', f'非テキスト添付省略={attachments}、重複イベント省略={duplicates}、内部推論/管理イベント除外={excluded}', f'不明形式={sum(unknown.values())}: {json.dumps(dict(unknown), ensure_ascii=False)}']
    preamble.extend(f'警告: {warning}' for warning in warnings)
    return '\n'.join(preamble) + '\n\n' + '\n'.join(blocks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session-id', required=True)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        output = args.output.expanduser().absolute()
        if os.path.lexists(output):
            raise ValueError('既存出力を上書きしません')
        body = extract(args.source.expanduser(), args.session_id)
        # 新設ディレクトリをすべて 0700 にする。既存親の権限は変更しない。
        missing, parent = [], output.parent
        while not parent.exists():
            missing.append(parent)
            parent = parent.parent
        for folder in reversed(missing):
            folder.mkdir(mode=0o700)
        fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            handle.write(body)
        print(f'session_id={args.session_id} output={output} bytes={output.stat().st_size}')
        return 0
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        print(f'ERROR {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
