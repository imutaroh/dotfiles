# dotfiles

macOS の開発環境の設定一式。Claude Code と Codex を中心に、Herdr と Neovim までをまとめて管理している。

## 見どころ

- **Herdr の自作 mod**: Claude の返答に赤を入れて送り返す `redpen` など 5 本（[一覧](.config/README.md#herdr-デスクトップアプリ)）
- **Claude Code と Codex の同等化**: 指示書・権限・フック・スキルを揃え、1 コマンドで点検できる（[.codex](.codex/README.md)）
- **自作 Neovim プラグイン**: [diffbase.nvim](https://github.com/imutaroh/diffbase.nvim)（編集画面を PR 差分にする）と [nudge.nvim](https://github.com/imutaroh/nudge.nvim)（コードへのコメントを AI エージェントに送る）

## 構成

| 場所 | 中身 |
|------|------|
| [.claude/](.claude/README.md) | Claude Code の設定とスキル |
| [.codex/](.codex/README.md) | Codex CLI の設定 |
| [.config/](.config/README.md) | Herdr・Neovim などのアプリ設定 |
| [Brewfile](Brewfile) | 入れるアプリの一覧 |
| [setup.sh](setup.sh) | パッケージの導入とリンクの作成 |
| [macos.sh](macos.sh) | macOS のシステム設定（手動で実行） |

## セットアップ

```bash
git clone https://github.com/imutaroh/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh
```

> [!WARNING]
> 作者の環境が前提で、多くのアプリを入れて既存の設定を置き換える。実行する前に `setup.sh` を読むこと。置き換えた設定は `~/.dotfiles-backup/` に退避する。Git の名前とメールは `~/.gitconfig.local` に書く。

## ライセンス

[MIT](LICENSE)。ただし、次の外部由来のファイルは対象外で、それぞれの作者の条件に従う。

| 場所 | 由来 |
|------|------|
| `.claude/skills/skill-creator/` | Anthropic（同梱の `LICENSE.txt`） |
| `.claude/skills/find-skills/` | [vercel-labs/skills](https://github.com/vercel-labs/skills) |
| `.claude/skills/hunk-review/` | [Hunk](https://github.com/modem-dev/hunk) |
| `.claude/skills/ctx-agent-history-search/` | ctx CLI |
