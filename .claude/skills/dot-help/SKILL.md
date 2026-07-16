---
name: dot-help
description: ユーザーの dotfiles 全体（Neovim / Ghostty / herdr / karabiner / zellij / zsh / lazygit / starship 等）について「〜するにはどのキー？」「このショートカット何？」「Cmd+◯ って何が起きる？」「この設定どこにある？」といった操作方法・キーバインド・設定の質問に、~/dotfiles と ~/.config の実際の設定を参照して回答する。nvim・ターミナル・シェルのキーバインドや設定に関する質問全般で使用（旧 nvim-help の後継）。どのディレクトリからでも使用可能。調査はサブエージェントに委譲してメインのコンテキストを節約する。
---

# dot-help

dotfiles 全体の設定を実際に読んで、キーバインドと設定の質問に答えるスキル。

## 実行方式（重要）: サブエージェント委譲

設定ファイルの捜索・読解は **Explore サブエージェントに委譲**し、メインセッションのコンテキストを消費しない。

1. 質問から下の「ツール別ルーティング」で対象ツールを特定する
2. Agent ツール（subagent_type: "Explore"）を起動し、次のテンプレートで依頼する:

   ```
   ユーザーの dotfiles に関する質問に答えるための調査。
   質問: <ユーザーの質問>
   まず <該当する references ファイルの絶対パス> を読んで前提知識を得ること。
   そのうえで実際の設定ファイルを読み、以下の形式で返答する:
   - キー → 何が起きるか → 定義元 ファイルパス:行番号
   - 関連するキーが近くに定義されていれば併記
   - 設定に存在しない場合は「未定義」と明言し、ツールのデフォルト挙動を（不確かなら断定せず）補足
   推測で埋めないこと。実ファイルの記述だけを根拠にする。
   ```

3. サブエージェントの返答はユーザーには見えない。**必ず自分の言葉で要約し、定義元 `ファイル:行` を添えて回答する**

例外: 対象ファイルと場所が確定している1問1答（例: 「Cmd+W って何だっけ」）は、該当ファイルだけ直接 grep して答えてよい。

## ツール別ルーティング

| 質問の対象 | 設定の場所 | references |
|---|---|---|
| Neovim / vim / AstroNvim | `~/dotfiles/.config/nvim/` | `references/nvim.md` を必ず先に読む |
| Ghostty / herdr / ターミナルの Cmd キー | `~/dotfiles/.config/ghostty/config`, `~/.config/herdr/config.toml` | `references/terminal.md` を必ず先に読む |
| zsh の alias・関数・環境変数 | `~/dotfiles/.zshrc` | 不要（直接読む） |
| karabiner | `~/dotfiles/.config/karabiner/karabiner.json` | 不要。現状カスタムルールなし（素の Default profile） |
| zellij | `~/dotfiles/.config/zellij/` | 不要。レガシー（現在はターミナル多重化を herdr に移行済み） |
| lazygit | `~/dotfiles/.config/lazygit/config.yml` | 不要（直接読む） |
| プロンプト表示 | `~/dotfiles/starship.toml` | 不要（直接読む） |
| インストール済みツール | `~/dotfiles/Brewfile` | 不要（直接読む） |

注意: `~/.config/herdr/` は dotfiles に**未ミラー**の例外（実体が `~/.config` 直下にある）。それ以外は `~/dotfiles` 配下が実体（シンボリックリンク元）なので、必ず `~/dotfiles` 側のパスで参照・回答する。

## 回答スタイル

- 「**キー** → 何が起きるか → 定義元 `ファイル:行`」の形式で簡潔に
- ツールをまたぐ質問（例: 「ペイン移動のキーは？」→ nvim と herdr の両方にある）は、両方の文脈を並べて答える
- ユーザーはキーバインドを「文字の連想で覚える」方針（例: Cmd+S = Spaces, Cmd+G = Goto）。新しいキーを提案するときはこの方針に従う
- 曖昧な回答や未確認の推測を返さない。設定に無いものは「無い」と言う
