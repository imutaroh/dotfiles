-- storyline.nvim: PR の差分を AI が「意味のあるチャプター」に分割して読ませる
-- 既存ツールとの住み分け:
--   neotree-diffstat … 普段の画面のまま差分の基準を切り替えて見る（読む順序は与えない）
--   octo      … PR コメントの読み書き・レビュー投稿
--   storyline … 「どの順で読むか」を AI に決めさせる読解モード
-- メインペインが実ファイルバッファなので gd / gr / hover がそのまま効くのが差別化点。
--
-- 注意: 2026-07 作成の新興リポ（star 数個・作者1人）のため commit を固定している。
-- 更新したいときは https://github.com/killinsun/storyline.nvim のコミットを確認して差し替える。
return {
  "killinsun/storyline.nvim",
  commit = "52d084859285b5d1f19d809e2e1de622bc4964c6",
  dependencies = { "lewis6991/gitsigns.nvim" },
  cmd = { "Storyline", "StorylinePick", "StorylineRead", "StorylineBackend", "StorylineRefresh" },
  keys = {
    { "<leader>gs", "<cmd>Storyline<cr>", desc = "Storyline: PR を章立てでレビュー" },
    { "<leader>gS", "<cmd>StorylinePick<cr>", desc = "Storyline: base ブランチを選んでレビュー" },
    { "<leader>sl", "<cmd>StorylineRead<cr>", desc = "Storyline: 既存コードをトピック単位で読む" },
  },
  opts = {
    -- cursor-agent は未インストールのため claude 固定（auto にすると探索が走る）
    backend = "claude",
    -- PR のタイトル・本文・差分（他人が書いた文章）を stdin で渡すので、ツールを一切持たせない。
    -- プロンプトは stdin で完結し、読むモードもパス一覧だけで動くのでツールは要らない。
    -- --setting-sources user は checkout 先の .claude/settings.json（hooks 含む）を読ませないため
    backends = {
      claude = { cmd = "claude", args = { "-p", "--tools", "", "--strict-mcp-config", "--setting-sources", "user" } },
    },
    -- 差分全文を claude -p に投げるので、1ファイルあたりの上限は既定より絞る
    max_diff_lines_per_file = 300,
    layout = "unified",
    sidebar_style = "tree",
    prompts = {
      analyze_extra = "章タイトル・要約・レビュー観点はすべて日本語で書くこと。",
      read_extra = "説明はすべて日本語で書くこと。",
      ask_extra = "日本語で、要点を箇条書きで簡潔に答えること。",
    },
    keymaps = {
      -- <leader>gl は既存マッピングと衝突なし（unified / split 切替）
      toggle_layout = "<leader>gl",
      preview = "<Tab>",
    },
  },
}
