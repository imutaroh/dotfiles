#!/bin/bash
# ask-gh-api-writes.sh の判定テスト。
#
#   bash .claude/hooks/ask-gh-api-writes.test.sh
#
# 全件が期待どおりなら 0、1 件でも違えば 1 で終わる。
#   ASK  = 確認を出す（フックが permissionDecision: "ask" を返す）
#   pass = 何も返さず、通常の判定に任せる
#
# 書き込みの取りこぼし（ASK のはずが pass）は、確認なしで書き込みが通る事故になる。
# 判定を変えるときは、先にここへケースを足す。

HOOK="$(cd "$(dirname "$0")" && pwd)/ask-gh-api-writes.sh"
total=0
failed=0

# check <ASK|pass> <コマンド全文>
check() {
    local expect=$1 cmd=$2 out got
    out=$(printf '%s' "$cmd" | jq -Rs '{tool_name: "Bash", tool_input: {command: .}}' | bash "$HOOK")
    if [ -n "$out" ]; then got=ASK; else got=pass; fi
    total=$((total + 1))
    if [ "$got" != "$expect" ]; then
        failed=$((failed + 1))
        printf 'NG  期待=%s 実際=%s | %s\n' "$expect" "$got" "$(printf '%s' "$cmd" | tr '\n' ' ' | cut -c1-100)"
    fi
}

# --- 書き込み: 確認を出す ---

# REST で -f / -F を付けると、gh api は暗黙で POST にする
check ASK 'gh api repos/o/r/pulls -f title=x -f head=b -f base=main'
check ASK 'cd x && gh api repos/o/r/issues -F title=x'

# メソッド指定（通常形、連結形、= 形、エンドポイントより後ろ）
check ASK 'gh api -X POST repos/o/r/issues'
check ASK 'gh api --method=DELETE repos/o/r/git/refs/heads/x'
check ASK 'gh api -XPATCH repos/o/r/pulls/1 -f state=closed'
check ASK 'gh api repos/o/r/pulls/1/merge -X PUT'

# 本文を渡す
check ASK 'gh api repos/o/r/issues --input body.json'
check ASK "gh api -X POST repos/o/r/rulesets --input - <<'EOF'
{\"name\":\"x\"}
EOF"

# graphql の mutation（1 行、複数行）と、中身を見られないファイル渡し
check ASK "gh api graphql -f query='mutation { createPullRequest(input:{}) { clientMutationId } }'"
check ASK "gh api graphql -f query='
mutation {
  addStar(input:{starrableId:\"x\"}) { clientMutationId }
}'"
check ASK 'gh api graphql -F query=@q.graphql'

# 命令の切り方: 継続行、複数行の引用符の後ろ、引用符内の |、$( ) 内の |、閉じていない引用符
check ASK 'gh api repos/o/r/issues \
  -f title=x'
check ASK "gh api repos/o/r/issues --jq '
  .[] | .title
' -f title=x"
check ASK "gh api repos/o/r --jq '.a | .b' -X POST"
check ASK 'gh api repos/$(echo x | tr a b) -X POST'
check ASK "echo \"don't\"; gh api -X POST repos/o/r/issues"

# 引用符の中に書いてあっても拾う（安全側）
check ASK 'echo "gh api -X POST repos/o/r/issues"'

# --- 読み取り: 何も返さない ---

check pass 'gh api repos/o/r/contents/README.md --jq .content'
check pass 'gh api user --jq .login'
check pass 'gh api repos/o/r/issues --paginate --jq ".[].title"'

# -X GET を明示すれば、-f は検索条件になる
check pass 'gh api -X GET search/issues -f q=foo'

# graphql の query は -f query=... を使うが読み取り
check pass "gh api graphql -f query='{viewer{login}}'"
check pass "gh api graphql -f query='
query {
  viewer { login }
}'"
check pass "GH_TOKEN=\$(gh auth token -u x) gh api graphql -f query='query { repository(owner:\"a\",name:\"b\"){ id } }'"

# 別の命令のフラグ（git commit -F、stat -f）を gh api のフィールドと取り違えない
check pass 'git commit -q -F msg.txt; gh api repos/o/r/contents/x --jq .sha'
check pass 'stat -f %m x && gh api user'

# gh api を含まない
check pass 'gh pr list'
check pass 'ls -la'
check pass 'echo graph api'

printf '%d 件中 %d 件が期待と違う\n' "$total" "$failed"
[ "$failed" -eq 0 ]
