-- ループ切替用の 4 つのダークテーマ
-- <leader>ub で順番に切り替わる（実装は astrocore.lua）
--
-- すべて透過背景設定で、Ghostty の壁紙が透けるようにしてある。
return {
  -- 🌃 Tokyo Night (storm variant)
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup {
        style = "storm",
        transparent = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = false },
          sidebars = "transparent",
          floats = "transparent",
        },
      }
    end,
  },

  -- ☕ Catppuccin Mocha
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup {
        flavour = "mocha",
        transparent_background = true,
        styles = {
          comments = { "italic" },
        },
        integrations = {
          neotree = true,
          treesitter = true,
          telescope = { enabled = true },
          which_key = true,
          mason = true,
          flash = true,
        },
      }
    end,
  },

  -- 🌊 Kanagawa Wave（葛飾北斎・墨と藍の和テイスト）
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup {
        theme = "wave",
        transparent = true,
        background = {
          dark = "wave",
          light = "lotus",
        },
      }
    end,
  },

  -- 🌹 Rose Pine（くすみピンク・エレガント）
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    config = function()
      require("rose-pine").setup {
        variant = "main",
        disable_background = true,
        disable_float_background = true,
        styles = {
          italic = false,
        },
      }
    end,
  },
}
