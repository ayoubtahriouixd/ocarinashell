#!/usr/bin/env python3
"""Shape text with HarfBuzz and convert it to a single SVG path (fonts become outlines).

text_to_path(font_file, text, size, wght=None, tracking=0.0) -> dict(d, width, ascent, descent)
  - size: font size in SVG user units
  - tracking: extra spacing in em (0.1 = 10% of size) added after each glyph
  - origin: x=0 at the left edge, y=0 at the baseline (glyphs extend to negative y)
"""
import functools
import io

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer


def _ntos(v):
    """Compact number formatting for path data (2 decimals is far below a pixel at any logo size)."""
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


@functools.lru_cache(maxsize=None)
def _load(font_file, wght):
    font = TTFont(font_file)
    if wght is not None and "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": wght}, inplace=False)
    buf = io.BytesIO()
    font.save(buf)
    data = buf.getvalue()
    return TTFont(io.BytesIO(data)), data


def text_to_path(font_file, text, size, wght=None, tracking=0.0):
    font, data = _load(font_file, wght)
    upem = font["head"].unitsPerEm
    face = hb.Face(data)
    hbfont = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(hbfont, buf, {"kern": True, "liga": True})
    glyph_set = font.getGlyphSet()
    order = font.getGlyphOrder()
    scale = size / upem
    pen = SVGPathPen(glyph_set, ntos=_ntos)
    x = 0.0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        name = order[info.codepoint]
        gx = (x + pos.x_offset) * scale
        gy = pos.y_offset * scale
        # flip Y: font units are y-up, SVG is y-down
        tpen = TransformPen(pen, (scale, 0, 0, -scale, gx, -gy))
        glyph_set[name].draw(tpen)
        x += pos.x_advance + tracking * upem
    width = (x - tracking * upem) * scale
    hhea = font["hhea"]
    return {
        "d": pen.getCommands(),
        "width": round(width, 2),
        "ascent": round(hhea.ascent * scale, 2),
        "descent": round(-hhea.descent * scale, 2),
    }


if __name__ == "__main__":
    import sys
    r = text_to_path(sys.argv[1], sys.argv[2], float(sys.argv[3]))
    print(r["width"], len(r["d"]))
