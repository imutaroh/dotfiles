# Claude のアカウントを入れ直すときのチェックリスト

新しい Mac にしたとき、または `/login` で別のアカウントに切り替えたときに上から順に進める。
コマンドで済む部分は `setup-claude-account.sh` が行い、ここにはブラウザで認証する手作業だけを書く。

## 0. 先に済ませること

- [ ] `~/dotfiles/setup.sh` を走らせてある（Claude Code 本体と `~/.claude/` のリンク）
- [ ] `claude` を起動して `/login` し、使うアカウントでログインした
- [ ] 会社や私的な MCP サーバーを使う Mac なら、非公開の一覧 `~/dotfiles-private/claude/mcp-servers.tsv` がある（書式は `setup-claude-account.sh` の先頭）

## 1. コマンドで入れる

```bash
~/dotfiles/setup-claude-account.sh
```

MCP サーバー（ユーザー全体）、マーケットプレイス、プラグインを登録する。既にあるものは飛ばすので、何度走らせてもよい。最後に接続状態が出る。

- [ ] 「失敗」の行が無い
- [ ] `./setup-claude-account.sh --check` が「足りないものはありません」で終わる

## 2. MCP サーバーの OAuth（Claude Code の中）

接続状態で `Needs authentication` と出たサーバーは、Claude Code の中で認証する。

1. `claude` を起動して `/mcp` を開く
2. 認証が要るサーバーを選び、Authenticate を押す
3. ブラウザが開くので、そのサービスにログインして許可する

- [ ] Linear（`linear`）
- [ ] Canva（`canva`）
- [ ] 非公開の一覧で足したサーバー

Linear のように同じ URL を 2 本登録しているサーバーは、1 本ずつ別のワークスペースで許可する。ブラウザで先に目的のワークスペースへ切り替えてから Authenticate を押すと取り違えない。

確認: もう一度 `claude mcp list` を走らせ、全部が `Connected` になっている。

## 3. claude.ai のコネクタ（ブラウザ）

Slack・Notion・Gmail・Google Calendar・Google Drive・Claude Docs などのコネクタは、Claude Code ではなくアカウントに付く。スクリプトでは繋げない。

1. ブラウザで <https://claude.ai/settings/connectors> を開く（右上のアカウントが切り替え先のものか確かめる）
2. 使うコネクタを 1 つずつ Connect し、各サービスの OAuth 画面で許可する
3. 繋ぎ終えたら Claude Code を起動し直す（起動中のセッションには出てこない）

前のアカウントで繋いでいたものは、次のコマンドで一覧できる（Claude Code が一度でも繋いだ claude.ai のコネクタの名前が残っている）。

```bash
jq -r '.claudeAiMcpEverConnected[]?' ~/.claude.json
```

- [ ] 上の一覧にあるコネクタを全部 Connect した
- [ ] Claude Code で `claude mcp list` を走らせ、`claude.ai ...` の行が `Connected` になっている

## 4. Claude in Chrome

ブラウザ操作の `claude-in-chrome` は Claude Code に組み込まれていて、MCP の登録は要らない。Chrome の拡張側を同じアカウントにする。

1. Chrome に拡張「Claude」（Claude in Chrome）を入れる。入っていれば拡張のメニューからログアウトする
2. 拡張に、Claude Code と同じアカウントでログインする
3. Claude Code で `/chrome` を開き、接続されていることを確かめる

- [ ] `/chrome` で接続済みと出る

## 5. スクリプトの対象外にしているもの

- 有効にしていないプラグイン（`settings.json` の `enabledPlugins` で `false` のもの）は入れない
- `image-view-bytes` などの自作 mod は `settings.json` の `env` で読み込むので、ここでは何もしない
- easel などの組み込みプラグインは Claude Code に入っていて、入れ直しは要らない
