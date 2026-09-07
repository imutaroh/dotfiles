#!/usr/bin/env python3
"""Claude Code の output style を Codex の developer_instructions に同期する。

Claude Code の output style（~/dotfiles/.claude/output-styles/*.md）の本文を、
Codex の `~/.codex/config.toml` のトップレベルキー `developer_instructions`
（TOML の複数行リテラル文字列）として書き込む。これは Codex がモデル入力に
注入する指示文字列で、Claude の output style と役割上ほぼ等価。

使い方:
  python3 sync-output-style.py --show                 # 現状 + 選べるスタイル一覧
  python3 sync-output-style.py 15sai                   # 15sai.md を developer_instructions に設定
  python3 sync-output-style.py default                 # developer_instructions を削除
  python3 sync-output-style.py 15sai --dry-run          # 書き込まず結果だけ表示
  python3 sync-output-style.py 15sai --config <path>    # 対象 config.toml を指定

スタイル名の一致判定は、対象ディレクトリ内の各 .md ファイルについて
frontmatter の `name:` またはファイル名 stem のどちらかと大文字小文字を
無視して一致するかで行う。

制限事項:
  - スタイル本文に `'''`（TOML の複数行リテラル文字列の終端記号）が
    含まれる場合は安全側に倒して中断する（本文の一部が欠落した状態で
    書き込まれる事故を防ぐ）。
  - frontmatter の簡易パーサは `key: value` の1行形式のみを想定する
    （YAML の折り返し `>` などは name/description の1行目までしか読まない）。
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
import tomllib
from pathlib import Path


DOTFILES_ROOT = Path(__file__).resolve().parents[2]
STYLES_DIR = DOTFILES_ROOT / ".claude" / "output-styles"

MARKER_RE = re.compile(r"^#\s*output style:")
KEY_RE = re.compile(r"^developer_instructions\s*=")


def list_style_files() -> list[Path]:
    if not STYLES_DIR.is_dir():
        return []
    return sorted(STYLES_DIR.glob("*.md"))


def parse_frontmatter(path: Path) -> dict[str, str]:
    """`---` で囲まれた frontmatter から name / description の1行目だけ拾う。"""
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        m = re.match(r"^(name|description)\s*:\s*(.*)$", line)
        if m:
            key, value = m.group(1), m.group(2).strip()
            value = value.strip('"').strip("'")
            if key not in meta:
                meta[key] = value
    return meta


def strip_frontmatter(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    if lines and lines[0].strip() == "---":
        end = None
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                end = i
                break
        if end is not None:
            body_lines = lines[end + 1 :]
            # frontmatter 直後の空行を1つだけ落として整える
            if body_lines and body_lines[0].strip() == "":
                body_lines = body_lines[1:]
            return "\n".join(body_lines)
    return text


def resolve_style(name: str) -> Path | None:
    name_lower = name.lower()
    for path in list_style_files():
        if path.stem.lower() == name_lower:
            return path
        meta = parse_frontmatter(path)
        if meta.get("name", "").lower() == name_lower:
            return path
    return None


def line_in_string_mask(lines: list[str]) -> list[bool]:
    """各行が複数行文字列（`'''` / `\"\"\"`）の内部かどうかを返す。

    developer_instructions の本文（Markdown）には `[見出し]` のような
    「行頭が `[` の行」が普通に出現しうる。これを TOML のテーブルヘッダや
    キー行と誤認識しないよう、開始〜終了デリミタの間にある行は
    mask[i]=True としてヘッダ/キー探索から除外する。開始行自体
    （`developer_instructions = '''`）は False（構文として扱う）、
    終了デリミタを含む行は True のまま返す（次行から False）。
    """
    in_string = False
    mask: list[bool] = []
    for line in lines:
        mask.append(in_string)
        toggles = line.count("'''") + line.count('"""')
        if toggles % 2 == 1:
            in_string = not in_string
    return mask


def find_first_header(lines: list[str]) -> int:
    mask = line_in_string_mask(lines)
    for i, line in enumerate(lines):
        if mask[i]:
            continue
        if line.lstrip().startswith("["):
            return i
    return len(lines)


def find_dev_instructions_span(
    lines: list[str], start: int, end: int
) -> tuple[int, int] | None:
    """developer_instructions キーのスパン（複数行リテラル文字列対応）を探す。

    直前行が `# output style: ...` マーカーコメントであればそれも含める。
    本文内部の行（`[見出し]` 等）はキー行として誤認識しないよう除外する。
    """
    mask = line_in_string_mask(lines)
    for i in range(start, end):
        if mask[i]:
            continue
        if KEY_RE.match(lines[i].strip()):
            after_eq = lines[i].split("=", 1)[1]
            span_end = i + 1
            if after_eq.count("'''") < 2:
                # 複数行: 閉じの ''' が現れる行まで延長する
                j = i + 1
                while j < end:
                    if "'''" in lines[j]:
                        span_end = j + 1
                        break
                    j += 1
                else:
                    span_end = end
            span_start = i
            if span_start > start and MARKER_RE.match(lines[span_start - 1].strip()):
                span_start -= 1
            return (span_start, span_end)
    return None


def build_block(style_name: str, style_file: Path, body: str) -> list[str]:
    marker = f"# output style: {style_name}（source: .claude/output-styles/{style_file.name}）"
    key_line = "developer_instructions = '''"
    body_lines = body.split("\n")
    # 末尾の余分な空行を削る（TOML の閉じ ''' 直前に不要な空行を残さない）
    while body_lines and body_lines[-1].strip() == "":
        body_lines.pop()
    closing_line = "'''"
    return [marker, key_line, *body_lines, closing_line]


def apply_set(original_text: str, style_name: str, style_file: Path) -> tuple[str, str]:
    if "'''" in style_name:
        raise ValueError("スタイル名に ''' を含めることはできません")

    body = strip_frontmatter(style_file)
    if "'''" in body:
        raise ValueError(
            f"{style_file} の本文に ''' が含まれるため TOML の複数行リテラル文字列に"
            "安全に埋め込めません。中断しました。"
        )

    trailing_newline = original_text.endswith("\n")
    lines = original_text.split("\n")
    if trailing_newline:
        lines = lines[:-1]

    first_header = find_first_header(lines)
    span = find_dev_instructions_span(lines, 0, first_header)
    new_block = build_block(style_name, style_file, body)

    if span is not None:
        s, e = span
        lines[s:e] = new_block
        action = f"developer_instructions を更新しました（{style_name}）"
    else:
        insert_at = first_header
        while insert_at > 0 and lines[insert_at - 1].strip() == "":
            insert_at -= 1
        lines[insert_at:insert_at] = new_block
        action = f"developer_instructions を新規設定しました（{style_name}）"

    new_text = "\n".join(lines)
    if trailing_newline or original_text == "":
        new_text += "\n"
    return new_text, action


def apply_default(original_text: str) -> tuple[str, str]:
    trailing_newline = original_text.endswith("\n")
    lines = original_text.split("\n")
    if trailing_newline:
        lines = lines[:-1]

    first_header = find_first_header(lines)
    span = find_dev_instructions_span(lines, 0, first_header)
    if span is None:
        return original_text, "developer_instructions は設定されていません（変更なし）"

    s, e = span
    del lines[s:e]
    # 削除した箇所の前後で空行が重複したら1つに畳む
    if 0 < s < len(lines) and lines[s - 1].strip() == "" and lines[s].strip() == "":
        del lines[s]

    new_text = "\n".join(lines)
    if trailing_newline or original_text == "":
        new_text += "\n"
    return new_text, "developer_instructions を削除しました（default に戻しました）"


def show_current(config_path: str) -> None:
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            text = f.read()
    else:
        text = ""
    lines = text.split("\n")
    first_header = find_first_header(lines)
    span = find_dev_instructions_span(lines, 0, first_header)

    print(f"設定ファイル: {config_path}")
    if span is None:
        print("developer_instructions: 未設定（Codex 既定の指示のみ）")
    else:
        s, e = span
        # マーカー行を除いた本文の先頭3行
        content_lines = [l for l in lines[s:e] if not MARKER_RE.match(l.strip())]
        preview = content_lines[1:-1][:3] if len(content_lines) >= 2 else []
        marker_line = next(
            (l for l in lines[s:e] if MARKER_RE.match(l.strip())), None
        )
        if marker_line:
            print(f"developer_instructions: 設定済み（{marker_line.strip()}）")
        else:
            print("developer_instructions: 設定済み（マーカーコメントなし・手動設定の可能性）")
        print("先頭3行:")
        for l in preview:
            print(f"  {l}")

    print()
    print("選べるスタイル一覧:")
    styles = list_style_files()
    if not styles:
        print(f"  ({STYLES_DIR} に .md が見つかりません)")
    for path in styles:
        meta = parse_frontmatter(path)
        name = meta.get("name", path.stem)
        desc = meta.get("description", "")
        print(f"  - {path.stem}  (name: {name})")
        if desc:
            print(f"      {desc}")
    print("  - default  (developer_instructions を削除)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "style",
        nargs="?",
        help="適用するスタイル名（ファイル名 stem または frontmatter の name）。'default' で削除",
    )
    parser.add_argument(
        "--config",
        default=os.path.expanduser("~/.codex/config.toml"),
        help="対象の config.toml パス（既定: ~/.codex/config.toml）",
    )
    parser.add_argument("--show", action="store_true", help="現状と選択肢を表示するだけ")
    parser.add_argument("--dry-run", action="store_true", help="書き込まず結果だけ表示")
    args = parser.parse_args()

    if args.show or not args.style:
        show_current(args.config)
        return 0

    path = args.config
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            original_text = f.read()
        try:
            tomllib.loads(original_text)
        except Exception as e:  # noqa: BLE001
            print(f"エラー: 既存の {path} が TOML として不正です: {e}", file=sys.stderr)
            return 2
    else:
        original_text = ""

    if args.style.lower() == "default":
        try:
            new_text, action = apply_default(original_text)
        except ValueError as e:
            print(f"エラー: {e}", file=sys.stderr)
            return 2
    else:
        style_file = resolve_style(args.style)
        if style_file is None:
            print(f"エラー: スタイル '{args.style}' が見つかりません。", file=sys.stderr)
            print("選べるスタイル:", file=sys.stderr)
            for p in list_style_files():
                print(f"  - {p.stem}", file=sys.stderr)
            return 2
        try:
            new_text, action = apply_set(original_text, args.style, style_file)
        except ValueError as e:
            print(f"エラー: {e}", file=sys.stderr)
            return 2

    try:
        tomllib.loads(new_text)
    except Exception as e:  # noqa: BLE001
        print(
            f"エラー: 変更後の内容が TOML として不正なため書き込みを中止しました: {e}",
            file=sys.stderr,
        )
        return 2

    print(action)

    if args.dry_run:
        print("(--dry-run のため書き込みは行っていません)")
        return 0

    target_dir = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(target_dir, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        dir=target_dir, prefix=".config.toml.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
