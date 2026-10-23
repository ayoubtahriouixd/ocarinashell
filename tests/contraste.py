#!/usr/bin/env python3
"""WCAG 2.1 contrast check of every theme's tokens (assets/data/themes/*.json).

Usage: tests/contraste.py [--all] [theme…]   (exit 1 if a required pair fails AA)

Pairs are graded by role: body text needs 4.5:1, large/bold text and UI glyphs 3:1
(WCAG 1.4.3 / 1.4.11). `textDim` labels sections and hints, so it is text too (4.5:1) since
the fase 17 visual QA; only Shinobi's is exempt (D-083).
Translucent tokens (#RRGGBBAA) are composited over the surface they sit on.
"""
import colorsys
import json
import pathlib
import sys

THEMES = pathlib.Path(__file__).resolve().parent.parent / "assets/data/themes"
SURFACES = ("bg", "surface0", "surface1", "surface2", "surface3")

# (foreground, backgrounds, minimum ratio, role)
PAIRS = [
    ("text", SURFACES, 4.5, "texto"),
    ("textMuted", SURFACES[:4], 4.5, "texto secundario"),
    ("accent", ("bg", "surface0", "surface1"), 3.0, "acento (iconos, títulos, foco)"),
    ("onAccent", ("accent", "accentPressed"), 4.5, "texto sobre botón de acento"),
    ("text", ("accentSoft@surface1",), 4.5, "texto sobre selección suave"),
    ("success", ("surface1",), 3.0, "estado"),
    ("warning", ("surface1",), 3.0, "estado"),
    ("error", ("surface1",), 3.0, "estado"),
    ("info", ("surface1",), 3.0, "estado"),
    ("outlineStrong", ("surface1",), 3.0, "borde de control (1.4.11)"),
    ("textDim", ("bg", "surface0", "surface1"), 4.5, "texto terciario (etiquetas de sección, pistas)"),
]
# 忍 Shinobi keeps its dim grey on OLED black on purpose (fewer lit sub-pixels): its textDim is reported, not failed
EXEMPT_THEME = {"shinobi": {"texto terciario (etiquetas de sección, pistas)"}}
# Controls are identified by their fill (surface2/3), not by the border, so 1.4.11 does not apply to it.
EXEMPT = {"decorativo (exento)", "borde de control (1.4.11)"}


def rgba(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    return r, g, b, a


def over(fg, bg):
    a = fg[3]
    return tuple(fg[i] * a + bg[i] * (1 - a) for i in range(3)) + (1.0,)


def lum(c):
    def ch(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def darker(c, factor):
    # Qt.darker(): HSV value / factor
    h, s, v = colorsys.rgb_to_hsv(*c[:3])
    return colorsys.hsv_to_rgb(h, s, v / factor) + (c[3],)


def resolve(colors, name):
    if name == "accentPressed":                 # Theme.qml: Qt.darker(accent, 1.12)
        return darker(rgba(colors["accent"]), 1.12)
    if "@" in name:
        top, base = name.split("@")
        return over(rgba(colors[top]), resolve(colors, base))
    return rgba(colors[name])


def check(theme, show_all):
    colors = theme["colors"]
    exempt = EXEMPT | EXEMPT_THEME.get(theme["id"], set())
    fails, lines = 0, []
    for fg, bgs, need, role in PAIRS:
        for bg in bgs:
            back = resolve(colors, bg)
            r = ratio(over(resolve(colors, fg), back), back)
            ok = r >= need
            if not ok and role not in exempt:
                fails += 1
            if show_all or not ok:
                mark = "✓" if ok else ("·" if role in exempt else "✗")
                lines.append(f"  {mark} {fg:>13} / {bg:<20} {r:5.2f} (≥{need}) {role}")
    return fails, lines


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    show_all = "--all" in sys.argv
    total = 0
    for path in sorted(THEMES.glob("*.json")):
        if path.stem == "index" or (args and path.stem not in args):
            continue
        theme = json.loads(path.read_text())
        fails, lines = check(theme, show_all)
        total += fails
        print(f"{theme['name']} ({theme['mode']}): {'AA ✓' if not fails else f'{fails} fallo(s) AA'}")
        print("\n".join(lines)) if lines else None
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
