-- snacks.image: 画像ファイルのプレビューと、markdown 内の画像のインライン表示
--
-- 以前は Neovim 0.12.1 × nvim-treesitter master (archived 2025-05-18) の組み合わせで、
-- snacks/image/doc.lua:241 → snacks/util/init.lua:464 → treesitter.lua:196 の経路で
-- "attempt to call method 'range' (a nil value)" が出てクラッシュしたため doc を切っていた。
-- 2026-10-05 に Vault の画像入り md 78 件で doc の画像探索（編集後の再パース込み）を
-- headless で回して再現しなかったので doc も有効に戻す。再発したら doc = { enabled = false }。
--
-- ImageMagick（magick）が必須。PNG でもサイズ取得の identify ステップで呼ばれ、
-- 無いと "Image Conversion Failed" になる。PNG 以外はこれで PNG に変換される。
return {
  "folke/snacks.nvim",
  opts = {
    image = {
      enabled = true,
      -- AstroNvim の既定（astronvim/plugins/snacks.lua）が doc を切っているので明示的に戻す
      doc = { enabled = true },
      -- ![[x.png]] は md と同じ階層の _assets/ から探す（Obsidian の attachmentFolderPath = ./_assets）
      -- 既定値の後ろに足す。リストは opts マージで添字ごとに上書きされるので既定値も書き並べる
      img_dirs = { "img", "images", "assets", "static", "public", "media", "attachments", "_assets" },
    },
  },
}
