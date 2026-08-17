#!/usr/bin/env python3
"""生成済みアイキャッチの中央スロットに、実物の書影／ポスターをそのまま合成する。

生成AIに書影を描かせると偽の装丁になるため、ここだけはピクセルを貼る。
土台は 1280x720 に正規化してから貼る。素材の最大が高さ500pxなので、
大きいキャンバスに載せると拡大＝ボケになるのを避けるため。
"""
import sys
from PIL import Image, ImageDraw

CANVAS = (1280, 720)
INK = (26, 35, 48)      # #1a2330 枠線
COVER_H_RATIO = 0.72    # 画面高に対する書影の高さ＝中央帯いっぱい
CENTER_Y_RATIO = 0.50
MAX_UPSCALE = 1.10      # これを超える拡大はボケるので許さない


def main(base_path, cover_path, out_path):
    base = Image.open(base_path).convert("RGB")
    if base.size != CANVAS:
        base = base.resize(CANVAS, Image.LANCZOS)
    cover = Image.open(cover_path).convert("RGB")
    W, H = base.size

    band_w = W // 3                    # 中央の1/3
    target_h = int(H * COVER_H_RATIO)
    ratio = min(target_h / cover.height, (band_w * 0.92) / cover.width)
    if ratio > MAX_UPSCALE:
        ratio = MAX_UPSCALE
    cover = cover.resize(
        (round(cover.width * ratio), round(cover.height * ratio)), Image.LANCZOS
    )

    x = W // 2 - cover.width // 2
    y = int(H * CENTER_Y_RATIO) - cover.height // 2

    base.paste(cover, (x, y))
    ImageDraw.Draw(base).rectangle(
        [x - 1, y - 1, x + cover.width, y + cover.height], outline=INK, width=1
    )

    base.save(out_path)
    print(f"{out_path}  cover={cover.width}x{cover.height} "
          f"(scale={ratio:.2f}, 高さの{cover.height/H:.0%}) at=({x},{y})")


if __name__ == "__main__":
    main(*sys.argv[1:4])
