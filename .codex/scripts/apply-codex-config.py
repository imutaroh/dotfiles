#!/usr/bin/env python3
"""~/.codex/config.toml に対する冪等なキー更新スクリプト。

Codex アプリ自身も config.toml を書き換えるため symlink 管理ができない。
このスクリプトはトップレベルキーと [tui] テーブル内の特定キーだけを、
既存の内容を壊さずに追記・置換する。

管理対象:
  - トップレベル `project_doc_fallback_filenames`
      → ["CLAUDE.md", ".claude/CLAUDE.md"] に設定（無ければ追加、あれば置換）
  - [tui].status_line   → 固定リストに設定（無ければ追加、あれば置換）
  - [tui].status_line_use_colors → true に設定（無ければ追加、あれば置換）
  - [tui].terminal_title → ["thread-title"] に設定（無ければ追加、あれば置換）
  - [tui].theme          → "imutaro-cool"（無ければ追加、あれば触らない）
  - [tui] テーブル自体が無ければファイル末尾に新規作成する

制限事項:
  - 対象キーが複数行にまたがる配列/リテラル文字列の場合、開き括弧の対応を
    数えて終端行まで含めて置換する。ただし極端に変則的な書式（同じ行に
    複数のキー定義が同居する等）までは想定していない。書き込み前後に
    tomllib で構文検証するため、想定外の壊れ方をした場合は書き込みを
    中止しエラーを報告する（サイレントに壊れたファイルを書かない）。

使い方:
  python3 apply-codex-config.py --check   # 差分があれば表示して exit 1
  python3 apply-codex-config.py --apply   # 変更を書き込み、変更点を表示
  python3 apply-codex-config.py --config /path/to/config.toml --check
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
import tomllib


# Codex の footer は1行だけ。狭いペイン（herdr の分割）では右側から欠けるため、
# Claude の statusline.sh で「上の行ほど重要」だった順に左から並べる。
# セッション名は terminal_title（herdr サイドバー）に出るので status_line からは外す。
# 識別子は codex-cli 0.153.4 のバイナリで存在を確認したもの（branch-changes = git dirty マーカー相当）。
STATUS_LINE_VALUE = (
    'status_line = ["model-with-reasoning", "git-branch", "branch-changes", '
    '"context-remaining", "five-hour-limit", "weekly-limit", '
    '"estimated-thread-cost", "current-dir"]'
)
# Claude の statusline.sh は 24bit 色付きなので Codex 側も色を有効にする
STATUS_LINE_USE_COLORS_VALUE = "status_line_use_colors = true"
TERMINAL_TITLE_VALUE = 'terminal_title = ["thread-title"]'
THEME_VALUE = 'theme = "imutaro-cool"'
PROJECT_DOC_FALLBACK_VALUE = (
    'project_doc_fallback_filenames = ["CLAUDE.md", ".claude/CLAUDE.md"]'
)


def line_in_string_mask(lines: list[str]) -> list[bool]:
    """各行が複数行文字列（`'''` / `\"\"\"`）の内部かどうかを返す。

    例えば developer_instructions の本文（Markdown）には `[見出し]` のような
    「行頭が `[` の行」が普通に出現しうる。これを TOML のテーブルヘッダと
    誤認識しないよう、開始〜終了デリミタの間にある行を mask[i]=True として
    ヘッダ/キー探索から除外する。開始行自体（`key = '''`）は False（構文
    として扱う）、終了デリミタを含む行は True のまま返す（次行から False）。
    素朴なトグル判定のため、コメント内の `'''` 等までは区別しない。
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
    """最初のテーブルヘッダ行のインデックスを返す（無ければ len(lines)）。"""
    mask = line_in_string_mask(lines)
    for i, line in enumerate(lines):
        if mask[i]:
            continue
        if line.lstrip().startswith("["):
            return i
    return len(lines)


def find_exact_header(lines: list[str], name: str) -> int | None:
    """`[name]` という厳密一致のヘッダ行を探す（サブテーブルは対象外）。"""
    mask = line_in_string_mask(lines)
    pat = re.compile(r"^\[" + re.escape(name) + r"\]\s*$")
    for i, line in enumerate(lines):
        if mask[i]:
            continue
        if pat.match(line.strip()):
            return i
    return None


def section_end(lines: list[str], header_idx: int) -> int:
    """header_idx の次に現れるテーブルヘッダ行（何であれ）の直前までを返す。"""
    mask = line_in_string_mask(lines)
    for i in range(header_idx + 1, len(lines)):
        if mask[i]:
            continue
        if lines[i].lstrip().startswith("["):
            return i
    return len(lines)


def find_key_span(
    lines: list[str], start: int, end: int, key: str
) -> tuple[int, int] | None:
    """[start, end) の範囲で `key = ...` を探し、その行スパンを返す。

    値が配列などで複数行にまたがる場合は `[` `]` の対応が取れるまで
    終端行を延長する（ネストした配列があっても素朴なカウントで対応する）。
    複数行文字列の内部にある行（例: developer_instructions の本文に
    `[見出し]` のような行が含まれる場合）はキー行として誤認識しない。
    """
    mask = line_in_string_mask(lines)
    key_re = re.compile(r"^" + re.escape(key) + r"\s*=")
    for i in range(start, end):
        if mask[i]:
            continue
        if key_re.match(lines[i].strip()):
            depth = lines[i].count("[") - lines[i].count("]")
            j = i
            while depth > 0 and j + 1 < end:
                j += 1
                depth += lines[j].count("[") - lines[j].count("]")
            return (i, j + 1)
    return None


def upsert_key(
    lines: list[str],
    start: int,
    end: int,
    key: str,
    value_line: str,
    replace_if_exists: bool = True,
    add_if_missing: bool = True,
) -> tuple[list[str], bool]:
    """[start, end) の範囲内で key を upsert する。変更有無を返す。"""
    span = find_key_span(lines, start, end, key)
    if span is not None:
        s, e = span
        if not replace_if_exists:
            return lines, False
        if lines[s:e] == [value_line]:
            return lines, False
        lines[s:e] = [value_line]
        return lines, True

    if not add_if_missing:
        return lines, False

    # 範囲末尾の空行より前に挿入して整える
    insert_at = end
    while insert_at > start and lines[insert_at - 1].strip() == "":
        insert_at -= 1
    lines[insert_at:insert_at] = [value_line]
    return lines, True


def apply_changes(original_text: str) -> tuple[str, list[str]]:
    trailing_newline = original_text.endswith("\n")
    lines = original_text.split("\n")
    if trailing_newline:
        lines = lines[:-1]

    changes: list[str] = []

    # 1. トップレベル project_doc_fallback_filenames
    first_header = find_first_header(lines)
    lines, changed = upsert_key(
        lines, 0, first_header, "project_doc_fallback_filenames",
        PROJECT_DOC_FALLBACK_VALUE,
    )
    if changed:
        changes.append(f"project_doc_fallback_filenames -> {PROJECT_DOC_FALLBACK_VALUE}")

    # 2. [tui] テーブルの存在確認・新規作成
    tui_idx = find_exact_header(lines, "tui")
    if tui_idx is None:
        if lines and lines[-1].strip() != "":
            lines = lines + [""]
        lines = lines + ["[tui]"]
        tui_idx = len(lines) - 1
        changes.append("[tui] テーブルを新規作成しました")

    # 3. status_line（無ければ追加、あれば置換）
    end = section_end(lines, tui_idx)
    lines, changed = upsert_key(lines, tui_idx + 1, end, "status_line", STATUS_LINE_VALUE)
    if changed:
        changes.append(f"tui.status_line -> {STATUS_LINE_VALUE}")

    # 3.5 status_line_use_colors（無ければ追加、あれば置換）
    end = section_end(lines, tui_idx)
    lines, changed = upsert_key(
        lines, tui_idx + 1, end, "status_line_use_colors", STATUS_LINE_USE_COLORS_VALUE
    )
    if changed:
        changes.append(f"tui.status_line_use_colors -> {STATUS_LINE_USE_COLORS_VALUE}")

    # 4. terminal_title（無ければ追加、あれば置換）
    end = section_end(lines, tui_idx)
    lines, changed = upsert_key(
        lines, tui_idx + 1, end, "terminal_title", TERMINAL_TITLE_VALUE
    )
    if changed:
        changes.append(f"tui.terminal_title -> {TERMINAL_TITLE_VALUE}")

    # 5. theme（無ければ追加、あれば触らない）
    end = section_end(lines, tui_idx)
    lines, changed = upsert_key(
        lines, tui_idx + 1, end, "theme", THEME_VALUE,
        replace_if_exists=False, add_if_missing=True,
    )
    if changed:
        changes.append(f"tui.theme -> {THEME_VALUE}（新規追加。既存値があれば変更しない）")

    new_text = "\n".join(lines)
    if trailing_newline or original_text == "":
        new_text += "\n"

    return new_text, changes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=os.path.expanduser("~/.codex/config.toml"),
        help="対象の config.toml パス（既定: ~/.codex/config.toml）",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="差分があれば表示して exit 1")
    mode.add_argument("--apply", action="store_true", help="変更を書き込む")
    args = parser.parse_args()

    path = args.config
    if not os.path.exists(path):
        print(f"エラー: {path} が存在しません", file=sys.stderr)
        return 2

    with open(path, "r", encoding="utf-8") as f:
        original_text = f.read()

    try:
        tomllib.loads(original_text)
    except Exception as e:  # noqa: BLE001
        print(f"エラー: 既存の {path} が TOML として不正です: {e}", file=sys.stderr)
        return 2

    new_text, changes = apply_changes(original_text)

    try:
        tomllib.loads(new_text)
    except Exception as e:  # noqa: BLE001
        print(
            f"エラー: 変更後の内容が TOML として不正なため書き込みを中止しました: {e}",
            file=sys.stderr,
        )
        return 2

    if not changes:
        print("変更なし")
        return 0

    for c in changes:
        print(c)

    if args.check:
        return 1

    # --apply: 一時ファイル経由で書き込む
    target_dir = os.path.dirname(os.path.abspath(path)) or "."
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
