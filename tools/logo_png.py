#!/usr/bin/env python3
"""Export the logo SVGs to transparent PNGs -> assets/logo/png/.

- icon: hicolor sizes 16…1024 (<= 32 px uses the flat icon, which stays legible that small)
- icon-kanji 512, mark / mark-flat 512 px wide, wordmark light/dark 1600 px wide
usage: python3 tools/logo_png.py [svgdir] [outdir]      (run logo_gen.py first; needs Chromium, see htmlshot.py)
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from htmlshot import browser, shot, svg_page  # noqa: E402

K = pathlib.Path(__file__).resolve().parent.parent
ICON_SIZES = (16, 24, 32, 48, 64, 128, 256, 512, 1024)


def viewbox(svg):
    m = re.search(r'viewBox="([-\d.]+) ([-\d.]+) ([\d.]+) ([\d.]+)"', svg)
    return float(m.group(3)), float(m.group(4))


def main(svgdir, outdir):
    svgdir, outdir = pathlib.Path(svgdir), pathlib.Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    jobs = []
    for s in ICON_SIZES:
        src = "ocarinashell-icon-flat.svg" if s <= 32 else "ocarinashell-icon.svg"
        jobs.append((src, f"ocarinashell-icon-{s}.png", s))
    jobs += [("ocarinashell-icon-kanji.svg", "ocarinashell-icon-kanji-512.png", 512),
             ("ocarinashell-mark.svg", "ocarinashell-mark-512.png", 512),
             ("ocarinashell-mark-flat.svg", "ocarinashell-mark-flat-512.png", 512),
             ("ocarinashell-wordmark-light.svg", "ocarinashell-wordmark-light-1600.png", 1600),
             ("ocarinashell-wordmark-dark.svg", "ocarinashell-wordmark-dark-1600.png", 1600)]
    with browser() as b:
        for src, name, w in jobs:
            svg = (svgdir / src).read_text()
            vw, vh = viewbox(svg)
            h = round(w * vh / vw)
            shot(b, outdir / name, html=svg_page(svg, w, h), w=w, h=h, transparent=True)
            print(f"{name:42s} {w}x{h}")


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0] if a else K / "assets/logo/svg", a[1] if len(a) > 1 else K / "assets/logo/png")
