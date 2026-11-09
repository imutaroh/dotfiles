#!/bin/bash
# PreToolUse フック（matcher: Bash）。`gh api` が書き込みになりうるときだけ、確認ダイアログを出させる。
#
# なぜ作ったか:
#   permissions.ask に `Bash(gh api *)` を置くと、読み取り（GET と graphql の query）まで
#   毎回確認になる。2026-11-02〜08 の会話ログでは gh api が約200回あり、書き込みは1割未満だった。
#   ask のパターンでは「graphql の -f query=... は読み取り、REST の -f は書き込み」を
#   書き分けられない（gh api は -f を付けると暗黙で POST にする）。
#   そこでコマンド全文を見て判定するフックに置き換えた。
#
# 動き:
#   - 書き込みの疑いがあるときだけ permissionDecision: "ask" を返す
#   - それ以外は何も出さず exit 0（通常の判定に任せる）
#   - 迷ったら ask 側に倒す。取りこぼしより余分な確認を選ぶ
#
# 判定の単位:
#   長いスクリプトに `git commit -F` や `stat -f` が混ざっていても誤検知しないよう、
#   引用符の外の ; & | 改行で命令を切り、`gh api` を含む命令の中だけで判定する。
#   引用符の中の改行や | は切らない（複数行の --jq の後ろに -X POST が来ても拾える）。
#   ( ) の中も切らない。引用符が閉じていないときは残り全部が 1 つの命令になり、ask 側に倒れる。
#
# 書き込みとみなす条件（大文字小文字は区別しない）:
#   1. -X / --method に POST・PUT・PATCH・DELETE
#   2. --input（本文をファイルや標準入力から渡す）
#   3. -f / -F / --field / --raw-field。ただし -X GET を明示しているときは除く。
#      graphql だけは、コマンド全体に "mutation" がある、または query をファイルから読む形（=@）のとき
#
# 限界:
#   graphql の query を別ファイルから渡す形は中身を見られないので、安全側で ask にしている。
#   `bash -c "..."` の中や、変数に組み立てたコマンドは、`gh api` が文字列として現れないと拾えない。

set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

# 全 Bash 呼び出しで走るので、gh api を含まないものは最初に弾く
case "$cmd" in
    *gh*api*) ;;
    *) exit 0 ;;
esac

PERL_SPLIT=$(cat <<'PERL'
local $/;
my $c = <STDIN>;
$c =~ s/\\\n/ /g;
my ($q, $depth, $cur, @seg) = ('', 0, '');
my @ch = split //, $c;
for (my $i = 0; $i < @ch; $i++) {
    my $x = $ch[$i];
    if ($q eq "'") { $cur .= $x; $q = '' if $x eq "'"; next; }
    if ($q eq '"') {
        if ($x eq "\\" && $i + 1 < @ch) { $cur .= $x . $ch[++$i]; next; }
        $cur .= $x; $q = '' if $x eq '"'; next;
    }
    if ($x eq "\\" && $i + 1 < @ch) { $cur .= $x . $ch[++$i]; next; }
    if ($x eq "'" || $x eq '"') { $q = $x; $cur .= $x; next; }
    if ($x eq '(') { $depth++; $cur .= $x; next; }
    if ($x eq ')') { $depth-- if $depth > 0; $cur .= $x; next; }
    if ($depth == 0 && $x =~ /[;&|\n]/) { push @seg, $cur; $cur = ''; next; }
    $cur .= $x;
}
push @seg, $cur;
for my $s (@seg) {
    next unless $s =~ /gh\s+api(\s|$)/;
    $s =~ s/\s+/ /g;
    print "$s\n";
}
PERL
)

whole=$(printf '%s' "$cmd" | tr '\n' ' ')

# perl が使えないときは、コマンド全体を 1 つの命令として扱う（誤検知は増えるが取りこぼしはしない）
segments=$(printf '%s' "$cmd" | perl -e "$PERL_SPLIT" 2>/dev/null) || segments=$whole

has_in() { printf '%s' "$1" | grep -Eiq -- "$2"; }

write=0
reason=""
mark() { [ "$write" = 1 ] || { write=1; reason=$1; }; }

while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    has_in "$seg" 'gh[[:space:]]+api([[:space:]]|$)' || continue

    # 1. 非 GET のメソッド指定（-XPOST、--method=PATCH、-X "DELETE" も拾う）
    if has_in "$seg" '(^|[[:space:]])(-X|--method)[[:space:]=]*.?(POST|PUT|PATCH|DELETE)'; then
        mark "POST/PUT/PATCH/DELETE を指定している"
    fi

    # 2. 本文をファイルや標準入力で渡す
    if has_in "$seg" '(^|[[:space:]])--input([[:space:]=]|$)'; then
        mark "--input で本文を渡している"
    fi

    # 3. フィールド指定
    if has_in "$seg" '(^|[[:space:]])(-f|-F|--field|--raw-field)([[:space:]=]|[^[:space:]-])'; then
        if has_in "$seg" '(^|[^[:alnum:]_-])graphql([^[:alnum:]_-]|$)'; then
            # query は複数行になりやすいので、mutation の有無はコマンド全体で見る
            if has_in "$whole" 'mutation|=@'; then
                mark "graphql の mutation、または query をファイルから読む形"
            fi
        elif ! has_in "$seg" '(^|[[:space:]])(-X|--method)[[:space:]=]*.?GET([^[:alnum:]]|$)'; then
            mark "フィールド指定は gh api では暗黙の POST になる"
        fi
    fi
done <<< "$segments"

if [ "$write" = 1 ]; then
    jq -nc --arg r "gh api の書き込みの疑い: $reason" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
fi

exit 0
