#!/usr/bin/env python3
"""Test images for 読 Yomu (fase 15): Japanese rendered as it shows on this screen (HiDPI 1.75, ~16 px text → 28 px),
horizontal and vertical (columns right to left), with the ground truth next to them (*.txt, no spaces/newlines)."""
import pathlib
import subprocess
from PIL import Image, ImageDraw, ImageFont

here = pathlib.Path(__file__).resolve().parent


def font(pattern: str, size: int) -> ImageFont.FreeTypeFont:
    path = subprocess.run(["fc-match", "-f", "%{file}", pattern], capture_output=True, text=True, check=True).stdout
    return ImageFont.truetype(path, size)


HORIZONTAL = [
    "吾輩は猫である。名前はまだ無い。",
    "どこで生れたかとんと見当がつかぬ。",
    "何でも薄暗いじめじめした所で",
    "ニャーニャー泣いていた事だけは記憶している。",
]
VERTICAL = [
    "春はあけぼの。やうやう白くなりゆく山ぎは、",
    "すこしあかりて、紫だちたる雲の",
    "細くたなびきたる。",
]


def horizontal(name: str, pattern: str, size: int, fg: str, bg: str) -> None:
    f = font(pattern, size)
    pad, gap = size, size // 2
    w = max(int(f.getlength(line)) for line in HORIZONTAL) + 2 * pad
    h = len(HORIZONTAL) * (size + gap) + 2 * pad
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    for i, line in enumerate(HORIZONTAL):
        d.text((pad, pad + i * (size + gap)), line, font=f, fill=fg)
    im.save(here / f"{name}.png")
    (here / f"{name}.txt").write_text("".join(HORIZONTAL) + "\n", encoding="utf-8")


def vertical(name: str, pattern: str, size: int, fg: str, bg: str) -> None:
    f = font(pattern, size)
    pad, colgap = size, size
    rows = max(len(c) for c in VERTICAL)
    w = len(VERTICAL) * (size + colgap) + 2 * pad
    h = rows * size + 2 * pad
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    for c, col in enumerate(VERTICAL):          # first column on the right
        x = w - pad - (c + 1) * (size + colgap) + colgap
        for r, ch in enumerate(col):
            if ch in "、。":                     # vertical punctuation sits top-right of its cell
                d.text((x + size * 0.55, pad + r * size - size * 0.45), ch, font=f, fill=fg)
            else:
                d.text((x, pad + r * size), ch, font=f, fill=fg)
    im.save(here / f"{name}.png")
    (here / f"{name}.txt").write_text("".join(VERTICAL) + "\n", encoding="utf-8")


if __name__ == "__main__":
    horizontal("horizontal", "Noto Sans CJK JP", 28, "#f4efe6", "#141216")
    horizontal("horizontal-mincho", "Shippori Mincho B1", 30, "#141216", "#f4efe6")
    vertical("vertical", "Noto Sans CJK JP", 30, "#141216", "#f4efe6")
    # wider than tall (a manga panel): the vertical pass must win on confidence, not on the aspect ratio
    VERTICAL = ["春はあけぼの。", "やうやう白く", "なりゆく山ぎは、", "すこしあかりて、", "紫だちたる雲の",
                "細くたなびきたる。", "夏は夜。月の", "ころはさらなり。"]
    vertical("vertical-wide", "Noto Sans CJK JP", 30, "#141216", "#f4efe6")
