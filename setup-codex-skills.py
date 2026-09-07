#!/usr/bin/env python3
"""個人スキルブリッジの検査と、明示適用によるリンク設置。標準ライブラリのみ。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys


def inspect(root, target):
    errors, pending, ready = [], [], []
    data = json.loads((root / '.codex/skill-bridge.json').read_text())
    if data.get('schema_version') != 1:
        raise ValueError('未対応の manifest schema_version')
    for relative in ('.codex/compatibility.md', '.codex/scripts/extract-session.py'):
        if not (root / relative).is_file():
            errors.append(f'共通依存ファイル欠落: {relative}')
    seen = set()
    if target.is_symlink() and not target.is_dir():
        errors.append(f'リンク先ディレクトリが壊れています: {target}')
    elif target.exists() and not target.is_dir():
        errors.append(f'リンク先がディレクトリではありません: {target}')
    for entry in data['skills']:
        name = entry['name']
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}', name) or name in seen:
            errors.append(f'名前が不正または重複: {name}')
            continue
        seen.add(name)
        source_rel = Path(entry['source'])
        if source_rel.is_absolute() or '..' in source_rel.parts:
            errors.append(f'正本のパスが不正: {name}')
            continue
        source = root / source_rel
        if not source.is_file():
            errors.append(f'正本欠落または壊れリンク: {source}')
        elif hashlib.sha256(source.read_bytes()).hexdigest() != entry['source_sha256']:
            errors.append(f'SOURCE_DRIFT {name}: 本文は実行時参照。metadata/互換性を再監査して manifest hash を更新してください')
        mode = entry['mode']
        if mode in ('existing', 'deferred'):
            continue
        if mode not in ('wrapper', 'adapted'):
            errors.append(f'不明な分類: {name}: {mode}')
            continue
        wrapper = root / '.codex/skills' / name
        if not (wrapper / 'SKILL.md').is_file():
            errors.append(f'ラッパー欠落: {wrapper}')
            continue
        document = (wrapper / 'SKILL.md').read_text()
        try:
            if not document.startswith('---\n'):
                raise ValueError('frontmatter 欠落')
            metadata = document.split('---', 2)[1]
            found_name = re.search(r'^name: (.+)$', metadata, re.M)
            found_description = re.search(r'^description: (.+)$', metadata, re.M)
            if not found_name or not found_description:
                raise ValueError('name/description 欠落')
            if found_name.group(1) != name or json.loads(found_description.group(1)) != entry['description']:
                raise ValueError('manifest と name/description 不一致')
        except (ValueError, IndexError) as exc:
            errors.append(f'ラッパー metadata 不正: {name}: {exc}')
            continue
        dest = target / name
        if dest.is_symlink():
            if not dest.exists():
                errors.append(f'壊れた既存リンク（上書きしません）: {dest}')
            elif dest.resolve() != wrapper.resolve():
                errors.append(f'既存リンクが別の場所を指しています: {dest}')
            else:
                ready.append(dest)
        elif os.path.lexists(dest):
            errors.append(f'既存ファイル/ディレクトリを保護: {dest}')
        else:
            pending.append((dest, wrapper.resolve()))
    actual = {p.name for p in (root / '.claude/skills').iterdir() if (p / 'SKILL.md').is_file()}
    if actual != seen:
        errors.append(f'manifest と正本一覧が不一致: 未分類={sorted(actual-seen)}, 欠落={sorted(seen-actual)}')
    return errors, pending, ready


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true', help='読取りのみ（既定）')
    mode.add_argument('--apply', action='store_true', help='全件検査後、不足リンクのみ設置')
    parser.add_argument('--target-dir', type=Path, default=Path.home() / '.agents/skills')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    target = args.target_dir.expanduser().absolute()
    try:
        errors, pending, ready = inspect(root, target)
        if errors:
            for error in errors:
                print(f'ERROR {error}', file=sys.stderr)
            print('適用なし: 全件事前検査で停止しました', file=sys.stderr)
            return 1
        if not args.apply:
            print(f'CHECK OK: 設置済み={len(ready)}, 未設置={len(pending)}（書込みなし）')
            for dest, _ in pending:
                print(f'MISSING {dest.name}')
            return 0
        # symlink は既存 entry を上書きしない。競合が発生したら今回作成分のみ戻す。
        created = []
        try:
            target.mkdir(parents=True, exist_ok=True)
            for dest, wrapper in pending:
                dest.symlink_to(wrapper, target_is_directory=True)
                created.append((dest, wrapper))
        except OSError:
            for dest, wrapper in reversed(created):
                if dest.is_symlink() and os.readlink(dest) == str(wrapper):
                    dest.unlink()
            raise
        print(f'APPLY OK: 新規={len(created)}, 変更なし={len(ready)}')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'ERROR {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
