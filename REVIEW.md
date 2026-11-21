# レビューで見るところ

このリポジトリの差分を見るときの確認。動かすコマンドは CLAUDE.md の「作業の進め方と確認」。

## 秘密と私的なファイル

- API キー、トークン、パスワード、クッキーが差分に無い
- 追跡しないもの（`.claude/CLAUDE.md`、`.claude/skills/agile-data-modeling/`、`.claude/skills/ap/`、`iphone/keep.txt`）をコミットしていない
- `settings.json` に `sync-settings.sh` が除くもの（`autoMode`、auto モードの既定、公式以外のプラグイン、`WebFetch` の無条件許可、`model`、マシン固有の herdr フック、同期スキルの `skillOverrides`）が戻っていない

## 設定の管理

- シンボリックリンクで配るファイルを、実体のコピーに置き換えていない
- `settings.json` の変更は、公開してよいものだけになっている
- 新しい許可や拒否を、頼まれた範囲を超えて足していない
- ディレクトリを増やしたら、CLAUDE.md と該当 README の構成が一致している

## スキル

- ディレクトリ形式（`.claude/skills/<名前>/SKILL.md`）。`.skill` 単体ファイルは無い
- Codex でも使うスキルは、本文を複製せず `.codex/skills/<名前>/SKILL.md` から正本を読む
- 本文を変えたら `.codex/skill-bridge.json` の `source_sha256` が一致している（`python3 setup-codex-skills.py --check`）

## 動作

- 完了の主張だけで終わっていない。CLAUDE.md にある確認コマンドの結果が、会話か PR に残っている
- シェルを変えたら `shellcheck` にかけている
