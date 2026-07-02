-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    -- change colorscheme
    -- ループ切替の起点として tokyonight-storm を採用。
    -- <leader>ub で 4 テーマ（tokyonight / catppuccin / kanagawa / rose-pine）を巡回。
    -- 全テーマで透過背景＆濃い色味なので Ghostty の壁紙透過と相性が良い。
    colorscheme = "tokyonight-storm",
    -- AstroUI allows you to easily modify highlight groups easily for any and all colorschemes
    highlights = {
      init = { -- 全テーマ共通：背景を透明化（Ghostty のぼかし効果を透過させる）
        Normal = { bg = "NONE" },
        NormalNC = { bg = "NONE" },
        NormalFloat = { bg = "NONE" },
        SignColumn = { bg = "NONE" },
        EndOfBuffer = { bg = "NONE" },
        LineNr = { bg = "NONE" },
        Folded = { bg = "NONE" },
        NonText = { bg = "NONE" },
        SpecialKey = { bg = "NONE" },
        VertSplit = { bg = "NONE" },
        WinSeparator = { bg = "NONE" },
        -- Neo-tree
        NeoTreeNormal = { bg = "NONE" },
        NeoTreeNormalNC = { bg = "NONE" },
        NeoTreeEndOfBuffer = { bg = "NONE" },
        NeoTreeWinSeparator = { bg = "NONE" },
        -- コメントを暗めにしてコード本体に視線が向くようにする
        -- (日本語コメントが長文でも視覚的に主張しすぎないようにする)
        Comment = { fg = "#6e7681", italic = true },
        ["@comment"] = { fg = "#6e7681", italic = true },
        ["@comment.documentation"] = { fg = "#6e7681", italic = true },
      },
    },
    -- Icons can be configured throughout the interface
    icons = {
      -- configure the loading of the lsp in the status line
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}
