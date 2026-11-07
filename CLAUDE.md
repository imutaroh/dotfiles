# dotfiles

macOS 用の個人設定ファイル管理リポジトリ。
全体の構成は README.md、各ディレクトリの詳細はその中の README を参照。

## 管理方式

- `setup.sh` でシンボリックリンクを作成して各設定ファイルを適用する
- `.config/` 以下はミラーリング方式（実際の配置場所と同じ構造）で管理
- `~/.claude/` 自体は実ディレクトリで、`CLAUDE.md` / `skills` / `scripts` / `statusline.sh` / `statusline-preview.sh` / `themes` / `hooks/play-sound.sh` / `sounds/*.wav` / `output-styles/15sai.md` が `setup.sh` の張る dotfiles へのシンボリックリンク
- `.claude/CLAUDE.md`（ユーザーレベルの指示書）は私的な内容を含むので gitignore 対象。実体は remote の無いローカル Git リポジトリ `~/dotfiles-private` にあり、ここからシンボリックリンクで参照する。編集はリンク先に対して行い、ブランチもそのリポジトリで切る。`setup.sh` はこのリンクを作らず、実体があるときだけ `~/.claude/CLAUDE.md` と `~/.codex/AGENTS.md` を張る
- `settings.json` は symlink 不可（`claude doctor` 等が実ファイルに置き換えるため）。`./sync-settings.sh` で実環境 → dotfiles へ明示的に取り込む。公開用に一部を除いて取り込むので、追跡版は実環境と一致しない（除く項目はスクリプトの先頭に書いてある）。`.claude/settings.json` を直接編集しない
- `.claude/mods/image-view-bytes/` は `~/.claude/settings.json` の `env` にある `CLAUDE_CODE_PLUGIN_DIRS` で読み込む（symlink にしない）。起動中のセッションには効かず、次に起動したセッションから効く。元の `image-view@claude-image-view` は無効にして併用しない
- Codex 側（`.codex/` と `setup-codex-skills.py`）の管理方式は `.claude/rules/codex.md` に分けてある。該当ファイルを触るときに読み込まれる
- `.claude/settings.local.json` はこのリポジトリ固有の設定として使える（gitignore 対象でコミットされない・設定の優先順位は user < project < local）
- `launchd/*.plist` は常駐エージェント定義。`setup.sh` が `__HOME__` を置き換えて `~/Library/LaunchAgents/` へコピーし `launchctl bootstrap` でロードする（symlink ではなくコピー）。実行するファイルが無いジョブは登録しない。`launchd/optional/` は対象外で、使うときに手で登録する
- Git の名前とメールは `~/.gitconfig.local` に置き、追跡しない
- `setup.sh` は既存の実ファイルや実ディレクトリを消さず、`~/.dotfiles-backup/<日時>/` へ退避してからリンクする

## 作業の進め方と確認

- `~/dotfiles` の main の作業ツリーは、複数の Claude が同時に作業場所にしている。`git switch` せず、`origin/main` から `.claude/worktrees/<名前>` に worktree を切って直す。`~/.claude/` のリンク先は main なので、worktree の変更は PR のマージと `~/dotfiles` での `git pull --ff-only` まで実環境に効かない
- main に自分の作業でない未コミットの変更があれば、PR に混ぜずに本人へ確認する
- 変更後の確認（読み取りのみ。Codex の 2 つはリンク先を見るので `~/dotfiles` で実行する。worktree からだと必ず NG になる）
  - `./sync-settings.sh --check`: 実環境の `settings.json` と追跡版の差分
  - `python3 setup-codex-skills.py --check`: Codex 側のスキルの対応表とリンク
  - `bash .codex/scripts/check-parity.sh --quick`: Claude Code と Codex の同等設定の一括点検

## 作業ルール

- シンボリックリンクで管理されるファイルは直接編集しない
- ディレクトリ構造を変更した場合は CLAUDE.md と README.md の整合性を確認・更新する
- コミット前に機密情報（APIキー、トークン等）が含まれていないか確認する
- 私的ファイル（`.claude/CLAUDE.md` / `.claude/skills/agile-data-modeling/` / `iphone/keep.txt`）はどれも Git の追跡から除外していて、このリポジトリの履歴には無い。`~/dotfiles-private` へのシンボリックリンクなので、`git clean -x` で消えたら張り直す。実体はリンク先のリポジトリで追跡している

## スキル管理ルール

- スキルは必ずディレクトリ形式で作成する。Claude 本文正本は `.claude/skills/skill-name/SKILL.md`、Codex 互換入口は `.codex/skills/skill-name/SKILL.md` に置き、本文を複製せず正本を実行時参照する
- `.skill` 単一ファイル形式は使わない
- 既存の `.skill` ファイルをディレクトリ形式に移行した場合は、古い `.skill` ファイルを即削除する

## リポジトリ配置

- ローカルリポジトリは `~/repos/<owner>/` で管理（オーナー別に整理）
  - 個人リポジトリ: `~/repos/imutaroh/`（GitHub アカウントは imutaroh の 1 つ。Imutaakihiro は旧名）
  - 会社・組織のリポジトリ: `~/repos/<組織名>/`（プロジェクト名で分けることもある）
  - 他人のリポジトリを参照用にクローンするときは `~/repos/others/`
- dotfiles のみ例外として `~/dotfiles/` に配置
