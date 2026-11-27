#!/bin/bash
# PreToolUse（Edit / Write / MultiEdit / NotebookEdit）のフック。
# git リポジトリの main / master の作業ツリーにあるファイルを書き換えようとしたら止める。
# CLAUDE.md の「main で直接編集しない」を、文章ではなく仕組みで守るためのもの。
#
# 通すもの:
#   - git リポジトリの外のファイル（~/.claude/projects のメモ、scratchpad など）
#   - main / master 以外のブランチ（worktree を含む）と、detached HEAD
#   - gitignore されたパス（.claude/tmp の一時ファイルなど）
# 止めるとき: 理由を stderr に出して終了コード 2。Claude Code はその文を Claude に返す。
# jq が無い・入力が読めないなど、判定できないときは止めない（終了コード 0）。

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[ -n "$path" ] || exit 0

case "$path" in
    /*) ;;
    *)
        cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
        [ -n "$cwd" ] || exit 0
        path="$cwd/$path"
        ;;
esac

# シンボリックリンクをたどって実体の場所で判定する（~/.claude/skills は ~/dotfiles の main を指す）。
if [ -e "$path" ]; then
    path="$(realpath "$path" 2>/dev/null)" || exit 0
fi

# まだ無いファイルは、存在する一番近い親ディレクトリで判定する。
dir="$(dirname "$path")"
while [ ! -d "$dir" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
done
dir="$(cd "$dir" 2>/dev/null && pwd -P)" || exit 0

top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)" || exit 0

case "$branch" in
    main|master) ;;
    *) exit 0 ;;
esac

if git -C "$top" check-ignore -q "$path" 2>/dev/null; then
    exit 0
fi

echo "止めました: $top は $branch ブランチです。main で直接編集しない決まりなので、作業ブランチか worktree を切ってから編集してください（CLAUDE.md「Git」）。" >&2
exit 2
