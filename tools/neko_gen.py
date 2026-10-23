#!/usr/bin/env python3
"""ネコ Vibe cat of 広場 Hiroba: a cyberpunk «vibing cat» (Ayoub, fase 15: replaces the «sol y luna» card and does
not have to match the system's look). A neon night scene the size of the card (284×150), in layers that share that
canvas so the shell stacks them in one box and animates each part (shell/modules/hiroba/NekoCard.qml):

  bg      sky, skyline with lit windows, horizon glow, perspective floor (rounded corners baked in)
  sign    vertical ネコ neon sign (flickers)
  body    the cat's shoulders in a jacket with neon trim
  head    head, ears, headphones, LED visor, nose and whiskers (nods around the neck: 196,106)
  fx      scanlines + vignette over everything

Neon glow needs SVG filters, which Qt's SVG renderer lacks: the layers are drawn here as SVG and rendered to PNG at
2× with rsvg-convert; layers with red also as -base/-tint (see REDS). usage: python3 tools/neko_gen.py [--preview out.png]
"""
import pathlib
import random
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "neko"
W, H, R = 284, 150, 20          # the card (Theme.island.sideCard × rowTop, cardRadius)
SCALE = 2

SILVER = "#d6dae0"     # grey neon (Ayoub: the neons red and grey)
RED = "#ff1f3d"
GREY = "#3d3c43"
PALE = "#9a9aa3"
FUR = "#18171b"
FUR_L = "#2a292f"
JACKET = "#0d0c0f"
HORIZON = 112

GLOW = ('<filter id="glow" x="-50%" y="-50%" width="200%" height="200%">'
        '<feGaussianBlur stdDeviation="{s}" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/>'
        '<feMergeNode in="SourceGraphic"/></feMerge></filter>')


def svg(body: str, defs: str = "", glow: float = 2.2) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W * SCALE}" height="{H * SCALE}">'
            f'<defs>{GLOW.format(s=glow)}<clipPath id="card"><rect width="{W}" height="{H}" rx="{R}"/></clipPath>'
            f"{defs}</defs>{body}</svg>\n")


def bg() -> str:
    rnd = random.Random(1987)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#070708"/><stop offset=".55" stop-color="#141317"/>'
            '<stop offset=".74" stop-color="#3a0a12"/><stop offset=".76" stop-color="#0e0c0f"/>'
            '<stop offset="1" stop-color="#050505"/></linearGradient>'
            f'<radialGradient id="sun" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="{RED}" stop-opacity=".55"/>'
            f'<stop offset="1" stop-color="{RED}" stop-opacity="0"/></radialGradient>'
            '<linearGradient id="floorfade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/>'
            '<stop offset="1" stop-color="#000" stop-opacity=".55"/></linearGradient>')
    out = f'<rect width="{W}" height="{H}" fill="url(#sky)"/>'
    for _ in range(26):                                     # stars
        out += (f'<circle cx="{rnd.uniform(4, W - 4):.1f}" cy="{rnd.uniform(4, 60):.1f}" r="{rnd.uniform(.3, .8):.2f}" '
                f'fill="#ffffff" opacity="{rnd.uniform(.25, .7):.2f}"/>')
    out += f'<ellipse cx="196" cy="{HORIZON}" rx="120" ry="34" fill="url(#sun)"/>'
    # two rows of skyline, the far one lighter; lit windows in neon colours
    for row, (col, base_h, step) in enumerate((("#1b1a1f", 34, 9), ("#0c0b0e", 22, 13))):
        x = -4
        while x < W:
            w = rnd.randint(10, 24) if row else rnd.randint(8, 18)
            h = base_h + rnd.randint(0, 30 if row == 0 else 26)
            top = HORIZON - h
            out += f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{col}"/>'
            if rnd.random() < .35:
                out += f'<rect x="{x + w / 2 - .4:.1f}" y="{top - 7}" width=".8" height="7" fill="{col}"/>'
            for wy in range(top + 4, HORIZON - 3, 5 if row else 4):
                for wx in range(x + 2, x + w - 2, 4):
                    if rnd.random() < (.18 if row else .1):
                        c = rnd.choice([SILVER, RED, PALE, "#ffd0d6"])
                        out += (f'<rect x="{wx}" y="{wy}" width="1.6" height="1.6" fill="{c}" '
                                f'opacity="{rnd.uniform(.45, .95):.2f}"/>')
            x += w + rnd.randint(0, step // 3)
    # horizon line and the perspective floor
    out += f'<rect x="0" y="{HORIZON}" width="{W}" height="{H - HORIZON}" fill="#070607"/>'
    grid = ""
    vx = 196
    for i in range(-14, 15):
        grid += f'<line x1="{vx + i * 8}" y1="{HORIZON}" x2="{vx + i * 46}" y2="{H}" />'
    y, gap = HORIZON + 2.0, 2.0
    while y < H:
        grid += f'<line x1="0" y1="{y:.1f}" x2="{W}" y2="{y:.1f}"/>'
        gap *= 1.45
        y += gap
    out += (f'<g stroke="{RED}" stroke-width=".7" opacity=".75" filter="url(#glow)">{grid}</g>'
            f'<rect x="0" y="{HORIZON}" width="{W}" height="{H - HORIZON}" fill="url(#floorfade)"/>'
            f'<line x1="0" y1="{HORIZON}" x2="{W}" y2="{HORIZON}" stroke="{SILVER}" stroke-width="1" filter="url(#glow)"/>')
    return svg(f'<g clip-path="url(#card)">{out}</g>', defs, 1.2)


def sign() -> str:
    # a vertical ネコ on a little dark plate, red neon tube
    plate = '<rect x="15" y="16" width="27" height="58" rx="5" fill="#0c0b0e" stroke="#2a282e" stroke-width="1"/>'
    text = "".join(f'<text x="28.5" y="{y}" font-family="Noto Sans CJK JP" font-weight="900" font-size="19" fill="none" '
                   f'stroke="{RED}" stroke-width="1.6" text-anchor="middle">{ch}</text>'
                   for ch, y in (("ネ", 40), ("コ", 64)))
    return svg(plate + f'<g filter="url(#glow)">{text}</g>', glow=2.0)


def body() -> str:
    d = "M168 102 C150 108 136 124 132 150 L262 150 C258 124 244 108 226 102 Z"
    trim = (f'<path d="M168 104 C176 116 188 122 197 122 C206 122 218 116 226 104" fill="none" stroke="{RED}" '
            'stroke-width="2" stroke-linecap="round"/>'
            f'<path d="M197 124 L197 150" stroke="{SILVER}" stroke-width="1.6"/>'
            f'<path d="M140 136 C146 124 152 116 160 110" fill="none" stroke="{SILVER}" stroke-width="1.4" '
            'stroke-linecap="round" opacity=".9"/>'
            f'<path d="M254 136 C248 124 242 116 234 110" fill="none" stroke="{RED}" stroke-width="1.4" '
            'stroke-linecap="round" opacity=".9"/>')
    neck = f'<path d="M178 92 L216 92 L222 108 L172 108 Z" fill="{FUR}"/>'
    badge = (f'<rect x="210" y="128" width="22" height="10" rx="2" fill="none" stroke="{PALE}" stroke-width="1"/>'
             '<text x="221" y="135.6" font-family="JetBrains Mono" font-weight="700" font-size="6" '
             f'fill="{PALE}" text-anchor="middle">V1BE</text>')
    return svg(neck + f'<path d="{d}" fill="{JACKET}" stroke="#26242a" stroke-width="1"/>'
               + f'<g filter="url(#glow)">{trim}{badge}</g>', glow=1.6)


def head() -> str:
    skull = "M196 40 C222 40 238 56 238 76 C238 96 220 106 196 106 C172 106 154 96 154 76 C154 56 170 40 196 40 Z"
    defs = (f'<clipPath id="left"><rect x="0" y="0" width="196" height="{H}"/></clipPath>'
            f'<clipPath id="right"><rect x="196" y="0" width="{W}" height="{H}"/></clipPath>'
            '<linearGradient id="visor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#202227"/>'
            '<stop offset="1" stop-color="#060607"/></linearGradient>')
    ears = (f'<path d="M160 64 L158 24 L188 44 Z" fill="{FUR}"/><path d="M164 56 L163 33 L181 45 Z" fill="#3a0d14"/>'
            f'<path d="M232 64 L234 24 L204 44 Z" fill="{FUR}"/><path d="M228 56 L229 33 L211 45 Z" fill="#3a0d14"/>')
    rim = (f'<g clip-path="url(#left)" filter="url(#glow)"><path d="{skull}" fill="none" stroke="{SILVER}" '
           f'stroke-width="1.4"/><path d="M160 64 L158 24 L188 44" fill="none" stroke="{SILVER}" stroke-width="1.2" '
           'stroke-linejoin="round"/></g>'
           f'<g clip-path="url(#right)" filter="url(#glow)"><path d="{skull}" fill="none" stroke="{RED}" '
           f'stroke-width="1.4"/><path d="M232 64 L234 24 L204 44" fill="none" stroke="{RED}" stroke-width="1.2" '
           'stroke-linejoin="round"/></g>')
    visor = ('<rect x="161" y="60" width="70" height="20" rx="10" fill="url(#visor)" stroke="#2a2d33" stroke-width="1"/>'
             f'<g filter="url(#glow)"><rect x="161" y="60" width="70" height="20" rx="10" fill="none" stroke="{SILVER}" '
             'stroke-width="1.2" opacity=".9"/></g>'
             '<path d="M168 64 Q190 61 222 63" fill="none" stroke="#ffffff" stroke-width="1" opacity=".35" '
             'stroke-linecap="round"/>')
    face = (f'<path d="M193 86 Q196 84 199 86 Q197 89 196 89 Q195 89 193 86 Z" fill="{RED}"/>'
            '<path d="M189 93 Q192.5 96.5 196 93 Q199.5 96.5 203 93" fill="none" stroke="#bfc3ca" stroke-width="1.2" '
            'stroke-linecap="round"/>'
            '<g filter="url(#glow)" stroke-width=".7" stroke-linecap="round" opacity=".9">'
            f'<path d="M170 88 L150 85 M170 92 L149 94" stroke="{SILVER}"/>'
            f'<path d="M222 88 L242 85 M222 92 L243 94" stroke="{RED}"/></g>')
    phones = (f'<g filter="url(#glow)"><path d="M156 70 C154 34 238 34 236 70" fill="none" stroke="{RED}" '
              'stroke-width="4.5" stroke-linecap="round"/></g>'
              '<path d="M156 70 C154 34 238 34 236 70" fill="none" stroke="#3a0d12" stroke-width="2" stroke-linecap="round"/>'
              '<rect x="146" y="62" width="15" height="26" rx="6" fill="#121114" stroke="#34323a" stroke-width="1"/>'
              '<rect x="231" y="62" width="15" height="26" rx="6" fill="#121114" stroke="#34323a" stroke-width="1"/>'
              f'<g filter="url(#glow)"><rect x="149" y="66" width="9" height="18" rx="4.5" fill="none" stroke="{SILVER}" '
              f'stroke-width="1.4"/><rect x="234" y="66" width="9" height="18" rx="4.5" fill="none" stroke="{SILVER}" '
              'stroke-width="1.4"/></g>')
    return svg(ears + f'<path d="{skull}" fill="{FUR}"/>'
               + f'<path d="M172 52 C182 46 210 46 220 52" fill="none" stroke="{FUR_L}" stroke-width="5" '
               + 'stroke-linecap="round" opacity=".8"/>'
               + rim + visor + face + phones, defs, 1.8)


def fx() -> str:
    lines = "".join(f'<rect x="0" y="{y}" width="{W}" height=".5" fill="#000" opacity=".22"/>' for y in range(0, H, 2))
    vign = ('<radialGradient id="v" cx=".55" cy=".5" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/>'
            '<stop offset="1" stop-color="#000" stop-opacity=".6"/></radialGradient>')
    return svg(f'<g clip-path="url(#card)">{lines}<rect width="{W}" height="{H}" fill="url(#v)"/>'
               f'<rect x=".5" y=".5" width="{W - 1}" height="{H - 1}" rx="{R - .5}" fill="none" stroke="{GREY}" '
               'stroke-opacity=".45" stroke-width="1"/></g>', vign)


LAYERS = {"bg": bg, "sign": sign, "body": body, "head": head, "fx": fx}


# The red neon follows the theme's accent in the shell (Ayoub, fase 17: «si pongo verde que sea verde – gris»).
# Every red of the scene is the accent mixed with white or black, and rasterising (strokes, blur glow, alpha) is
# linear in those colours, so each layer with red is rendered twice: accent = black (`-base`) and accent = white;
# their difference is `-tint`, exactly how much accent each pixel holds. NekoCard's shader draws base + tint × accent
# (with #ff1f3d it gives back the original). The greys never change.
REDS = {"#ff1f3d": (1.0, None), "#ffd0d6": (0.2, "#ffffff"), "#3a0d14": (0.225, "#000000"),
        "#3a0d12": (0.225, "#000000")}


def with_accent(text: str, accent: str) -> str:
    """The SVG with its reds rebuilt from `accent` (#000000 or #ffffff): red = accent·k + other·(1−k)."""
    a = int(accent[1:3], 16)
    for red, (k, other) in REDS.items():
        o = 0 if other is None else int(other[1:3], 16)
        v = round(a * k + o * (1 - k))
        text = text.replace(red, f"#{v:02x}{v:02x}{v:02x}")
    return text


def rsvg(svg_text: str, png: pathlib.Path) -> None:
    src = OUT / "src" / f"{png.stem}.svg"
    src.write_text(svg_text, encoding="utf-8")
    subprocess.run(["rsvg-convert", "-o", str(png), str(src)], check=True)


def render(name: str, text: str) -> pathlib.Path:
    (OUT / "src").mkdir(parents=True, exist_ok=True)
    png = OUT / f"{name}.png"
    rsvg(text, png)
    if any(r in text for r in REDS):
        base, white, tint = (OUT / f"{name}-{k}.png" for k in ("base", "white", "tint"))
        rsvg(with_accent(text, "#000000"), base)
        rsvg(with_accent(text, "#ffffff"), white)
        # tint = white − base on RGB, with the (shared) alpha of the layer
        subprocess.run(["magick", "(", str(white), "-alpha", "off", ")", "(", str(base), "-alpha", "off", ")",
                        "-compose", "difference", "-composite", "(", str(white), "-alpha", "extract", ")",
                        "-alpha", "off", "-compose", "copy_opacity", "-composite",
                        "-define", "png:color-type=6", str(tint)], check=True)    # RGBA, never «grey + alpha»
        white.unlink()
        (OUT / "src" / f"{name}-white.svg").unlink()
    return png


def main(argv: list[str]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pngs = [render(n, fn()) for n, fn in LAYERS.items()]
    if "--preview" in argv:
        dst = argv[argv.index("--preview") + 1]
        cmd = ["magick", str(pngs[0])]
        for p in pngs[1:]:
            cmd += [str(p), "-composite"]
        subprocess.run(cmd + [dst], check=True)
        print(dst)


if __name__ == "__main__":
    main(sys.argv[1:])
