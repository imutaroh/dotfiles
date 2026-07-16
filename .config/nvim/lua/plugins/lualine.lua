-- lualine ステータスライン設定
-- モード表示を含むシンプルなステータスライン

---@type LazySpec
return {
  -- heirline を無効化
  { "rebelot/heirline.nvim", enabled = false },

  -- lualine を追加
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          -- ファイル名だけでなくプロジェクトルートからの相対パスを表示
          {
            "filename",
            path = 1,         -- 0=名前のみ / 1=相対パス / 2=絶対パス / 3=~ 短縮絶対パス
            shorting_target = 40, -- 端末幅が狭い時に短縮を開始する閾値
            symbols = {
              modified = " ●",  -- 未保存
              readonly = " ",  -- 読み取り専用
              unnamed = "[No Name]",
              newfile = "[New]",
            },
          },
        },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
}
