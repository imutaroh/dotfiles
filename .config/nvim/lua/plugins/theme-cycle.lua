-- 🎨 4 つのダークテーマをループ切替する <leader>ub キーマップ
--
-- なぜ別ファイル？
--  astrocore.mappings 経由で登録すると AstroNvim 標準の <leader>ub に
--  上書きされる可能性があるため、VimEnter 後に直接 vim.keymap.set で登録して
--  最終勝者になるようにする。:CycleTheme コマンドもデバッグ用に併設。

-- name = :colorscheme コマンドに渡す名前
-- match = vim.g.colors_name と比較する前方一致パターン（Lua パターン形式）
--         一部プラグインは :colorscheme XXX-variant で適用しても
--         vim.g.colors_name を XXX に書き換える（rose-pine 等）ので、
--         単純な完全一致だとループから外れる事故が起きる
local themes = {
  { name = "tokyonight-storm", match = "^tokyonight",   icon = "🌃", label = "Tokyo Night Storm" },
  { name = "catppuccin-mocha", match = "^catppuccin",   icon = "☕", label = "Catppuccin Mocha" },
  { name = "kanagawa-wave",    match = "^kanagawa",     icon = "🌊", label = "Kanagawa Wave" },
  { name = "rose-pine-main",   match = "^rose%-pine",   icon = "🌹", label = "Rose Pine" },
}

local function force_transparent_bg()
  local hi = vim.api.nvim_set_hl
  for _, group in ipairs {
    "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn",
    "EndOfBuffer", "LineNr", "Folded", "NonText", "MsgArea",
    "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
    "TelescopeNormal", "TelescopeBorder",
  } do
    hi(0, group, { bg = "NONE" })
  end
  hi(0, "Comment", { fg = "#7d8590", italic = true })
end

local function cycle_theme()
  local current = vim.g.colors_name or ""
  local next_idx = 1
  for i, t in ipairs(themes) do
    -- 完全一致 OR 前方一致パターンにマッチした方を採用
    if t.name == current or current:match(t.match) then
      next_idx = (i % #themes) + 1
      break
    end
  end
  local theme = themes[next_idx]

  vim.opt.background = "dark"
  local ok, err = pcall(vim.cmd.colorscheme, theme.name)
  if not ok then
    vim.notify(
      ("テーマ読込失敗: %s\n%s"):format(theme.name, tostring(err)),
      vim.log.levels.ERROR
    )
    return
  end

  -- カラースキーム適用 → astroui 等の上書き → そのあとにこっちで再上塗り
  vim.schedule(force_transparent_bg)
  vim.notify(theme.icon .. " " .. theme.label, vim.log.levels.INFO)
end

-- :CycleTheme でも呼べる（デバッグ用）
vim.api.nvim_create_user_command("CycleTheme", cycle_theme, {
  desc = "🎨 テーマをループ切替",
})

-- VimEnter 後にキーマップ登録（AstroNvim の <leader>ub より後に最終登録）
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("ThemeCycleKeymap", { clear = true }),
  callback = function()
    vim.keymap.set("n", "<leader>ub", cycle_theme, {
      desc = "🎨 テーマをループ切替",
      silent = true,
    })
    -- 起動直後にも透過を強制（startup の colorscheme で astroui 由来の bg が
    -- 微妙に残るケースがあるため）
    force_transparent_bg()
  end,
})

-- ColorScheme 切替時に常に透過を再適用する保険
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ThemeCycleTransparent", { clear = true }),
  callback = function()
    vim.schedule(force_transparent_bg)
  end,
})

return {}
