#!/usr/bin/env python3
"""OcarinaShell logo system generator — red on white (紅白).

Everything is built from one geometry definition so the SVGs, the PNG exports and the
QML component (logo-geometry.json) stay pixel-consistent. No SVG filters are used:
glow, shadow and specular highlight are gradients, so the same look can be reproduced
in QtQuick Shapes (cheap, GPU friendly, no blur passes).

usage: OCARINA_FONTS=<dir> python3 tools/logo_gen.py [outdir=assets/logo/svg]
Importable: boot_assets.py and mockups reuse the building blocks.
"""
import json
import math
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from textpath import text_to_path  # noqa: E402

K = pathlib.Path(__file__).resolve().parent.parent
FONT_DIRS = [pathlib.Path(p).expanduser() for p in
             os.environ.get("OCARINA_FONTS", "~/.local/share/fonts/ocarinashell:~/.local/share/fonts:/usr/share/fonts").split(":")]


def find_font(prefix, contains=""):
    """First .ttf/.otf whose name starts with prefix (and contains `contains`) in the font dirs."""
    for d in FONT_DIRS:
        if d.is_dir():
            for f in sorted(d.rglob(f"{prefix}*")):
                if f.suffix.lower() in (".ttf", ".otf") and contains in f.name:
                    return str(f)
    raise SystemExit(f"font not found: {prefix}*{contains}* (set OCARINA_FONTS)")


# ----------------------------------------------------------------------------- palette (紅 kurenai on 白 shiro)
C = {
    "paper0": "#ffffff", "paper1": "#f5f1ec",          # icon background (white, faint warm edge)
    "pattern": "#d8002f",                               # seigaiha lines (very low opacity)
    "body0": "#ff7466", "body1": "#ea1f35", "body2": "#a3001f",
    "belly": "#56000f", "hole": "#3a000c",
    "mouth0": "#ffb3aa", "mouth1": "#f0574f",
    "wave0": "#ff5a48", "wave1": "#d9002f",
    "seal0": "#ef1d3c", "seal1": "#b3001e",
    "shadow": "#7a0016",
    "red": "#e60033",                                   # 赤 aka — the brand red
    "inkLight": "#f4efe6", "inkDark": "#18171c",        # wordmark text on dark / on light
    "mutedLight": "#a8a29b", "mutedDark": "#8a847d",
    "petal": "#f37f8f",
}

# ----------------------------------------------------------------------------- geometry (local ocarina space)
BODY = ("M -200 10 C -204 -62 -118 -96 -18 -93 C 84 -90 172 -70 206 -16 "
        "C 226 16 200 56 148 72 C 68 96 -42 106 -122 91 C -176 81 -197 50 -200 10 Z")
MOUTH = {"x": -192, "y": -134, "w": 78, "h": 60, "rx": 16, "rot": -22, "cx": -153, "cy": -104}
WINDOW = {"x": -124, "y": -94, "w": 34, "h": 12, "rx": 6, "rot": -5, "cx": -107, "cy": -88}
HOLES = [  # x, y, r  (top row left->right, then lower row)
    (-58, -42, 14.5), (-4, -48, 14.5), (50, -47, 14.5), (102, -37, 13.5),
    (-16, 31, 13), (46, 26, 13),
]
TIP = (206, -16)
WAVES = [(36, 14, 1.0), (66, 12, 0.8)]   # radius, stroke width, opacity
WAVE_A0, WAVE_A1 = -80, 0                 # degrees, around the tip
PLACE = {"cx": 226, "cy": 300, "s": 0.82, "rot": -14}   # placement inside the 512 icon
MARK_PLACE = {"cx": 210, "cy": 160, "s": 0.82, "rot": -14}  # placement in the mark (viewBox MARK_BOX)
MARK_BOX = (20, 30, 430, 270)
PETAL = ("M 0 13 C -5 9 -8 2 -7 -4 C -6 -9 -3 -11 -1.2 -10.5 L 0 -8.6 L 1.2 -10.5 "
         "C 3 -11 6 -9 7 -4 C 8 2 5 9 0 13 Z")


def g2(x, y, p=PLACE):
    a = math.radians(p["rot"])
    xr = x * math.cos(a) - y * math.sin(a)
    yr = x * math.sin(a) + y * math.cos(a)
    return p["cx"] + p["s"] * xr, p["cy"] + p["s"] * yr


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


# ----------------------------------------------------------------------------- glyph outlines
F_BRUSH, F_BRAND, F_KANA = find_font("YujiSyuku"), find_font("Unbounded"), find_font("ZenKakuGothicNew", "Medium")
SEAL_KANJI = text_to_path(F_BRUSH, "殻", 60)
WORD_OC = text_to_path(F_BRAND, "Ocarina", 150, wght=600)
WORD_SH = text_to_path(F_BRAND, "Shell", 150, wght=600)
KATA = text_to_path(F_KANA, "オカリナ・シェル", 44, tracking=0.32)
LETTERS = [text_to_path(F_BRAND, ch, 150, wght=600) for ch in "OcarinaShell"]
GAP = 8  # extra space between "Ocarina" and "Shell"


# ----------------------------------------------------------------------------- building blocks
def defs(u, mono=False):
    if mono:
        return f'<defs><clipPath id="{u}clip"><path d="{BODY}"/></clipPath></defs>'
    return f"""<defs>
  <radialGradient id="{u}bg" cx="40%" cy="30%" r="85%">
    <stop offset="0" stop-color="{C['paper0']}"/><stop offset=".62" stop-color="{C['paper0']}"/><stop offset="1" stop-color="{C['paper1']}"/>
  </radialGradient>
  <linearGradient id="{u}body" x1="-185" y1="-95" x2="175" y2="95" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="{C['body0']}"/><stop offset=".45" stop-color="{C['body1']}"/><stop offset="1" stop-color="{C['body2']}"/>
  </linearGradient>
  <linearGradient id="{u}belly" x1="0" y1="-5" x2="0" y2="100" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="{C['belly']}" stop-opacity="0"/><stop offset="1" stop-color="{C['belly']}" stop-opacity=".5"/>
  </linearGradient>
  <linearGradient id="{u}rim" x1="-200" y1="-90" x2="120" y2="-40" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset=".55" stop-color="#fff" stop-opacity=".28"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="{u}mouth" x1="0" y1="-134" x2="0" y2="-74" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="{C['mouth0']}"/><stop offset="1" stop-color="{C['mouth1']}"/>
  </linearGradient>
  <radialGradient id="{u}spec" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(-92 -60) rotate(-6) scale(96 26)">
    <stop offset="0" stop-color="#fff" stop-opacity=".72"/><stop offset=".6" stop-color="#fff" stop-opacity=".2"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="{u}warm" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(200 -10) scale(120 110)">
    <stop offset="0" stop-color="#ffb08a" stop-opacity=".45"/><stop offset="1" stop-color="#ffb08a" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="{u}glow" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(0 30) scale(250 150)">
    <stop offset="0" stop-color="{C['body1']}" stop-opacity=".16"/><stop offset="1" stop-color="{C['body1']}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="{u}shadow" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(0 124) scale(178 21)">
    <stop offset="0" stop-color="{C['shadow']}" stop-opacity=".34"/><stop offset="1" stop-color="{C['shadow']}" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="{u}wave" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0" stop-color="{C['wave1']}"/><stop offset="1" stop-color="{C['wave0']}"/>
  </linearGradient>
  <linearGradient id="{u}seal" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{C['seal0']}"/><stop offset="1" stop-color="{C['seal1']}"/>
  </linearGradient>
  <linearGradient id="{u}shine" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".32"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="{u}fade" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".6" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity="1"/>
  </linearGradient>
  <mask id="{u}seimask"><rect width="512" height="512" fill="url(#{u}fade)"/></mask>
  <clipPath id="{u}clip"><path d="{BODY}"/></clipPath>
  <clipPath id="{u}sq"><rect width="512" height="512" rx="114"/></clipPath>
</defs>"""


def seigaiha(u, w=512, h=512, R=34, y0=300, op=0.075):
    """Explicit seigaiha (青海波) field drawn top->bottom so lower fans overlap the upper ones."""
    out = [f'<g opacity="{op}" mask="url(#{u}seimask)">']
    row, y = 0, y0
    while y < h + R:
        x = -(R if row % 2 else 0)
        while x < w + 2 * R:
            out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{R}" fill="{C["paper0"]}"/>')
            for k in (1.0, 0.72, 0.44):
                out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(R * k - 2)}" fill="none" stroke="{C["pattern"]}" stroke-width="2.4"/>')
            x += 2 * R
        y += R / 2
        row += 1
    out.append("</g>")
    return "".join(out)


def holes_svg(cls=True, flat=False):
    out = []
    for i, (x, y, r) in enumerate(HOLES):
        c = f' class="os-hole os-h{i}"' if cls else ""
        if flat:
            out.append(f'<circle{c} cx="{x}" cy="{y}" r="{r}" fill="{C["paper0"]}"/>')
            continue
        out.append(
            f'<g{c}><circle cx="{x}" cy="{y}" r="{r}" fill="{C["hole"]}"/>'
            f'<path d="M {f(x - r * .74)} {f(y + r * .42)} A {r} {r} 0 0 0 {f(x + r * .74)} {f(y + r * .42)}" '
            f'fill="none" stroke="#fff" stroke-opacity=".3" stroke-width="2.6" stroke-linecap="round"/></g>')
    return "".join(out)


def mouth_svg(u, fill=None):
    m = MOUTH
    fill = fill or f"url(#{u}mouth)"
    return (f'<rect x="{m["x"]}" y="{m["y"]}" width="{m["w"]}" height="{m["h"]}" rx="{m["rx"]}" '
            f'fill="{fill}" transform="rotate({m["rot"]} {m["cx"]} {m["cy"]})"/>')


def window_svg(fill):
    w = WINDOW
    return (f'<rect x="{w["x"]}" y="{w["y"]}" width="{w["w"]}" height="{w["h"]}" rx="{w["rx"]}" fill="{fill}" '
            f'transform="rotate({w["rot"]} {w["cx"]} {w["cy"]})"/>')


def ocarina_svg(u, p=PLACE, mode="gloss", glow=True, cls=True, holes=True):
    """mode: gloss (3D red), flat (solid red, white holes), mono (currentColor, holes knocked out).
    holes=False leaves the finger holes out (boot layers animate them separately)."""
    t = f'translate({f(p["cx"])} {f(p["cy"])}) rotate({p["rot"]}) scale({p["s"]})'
    if mode == "mono":
        knock = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#000"/>' for x, y, r in HOLES)
        return f"""<g transform="{t}">
  <mask id="{u}mh" maskUnits="userSpaceOnUse" x="-260" y="-200" width="520" height="400">
    <rect x="-260" y="-200" width="520" height="400" fill="#fff"/>{knock}{window_svg('#000')}
  </mask>
  <g mask="url(#{u}mh)">{mouth_svg(u, 'currentColor')}<path d="{BODY}" fill="currentColor"/></g>
</g>"""
    if mode == "flat":
        c = ' class="os-body"' if cls else ""
        return f"""<g transform="{t}"><g{c}>
  {mouth_svg(u, C['mouth1'])}<path d="{BODY}" fill="{C['red']}"/>{window_svg(C['paper0'])}{holes_svg(cls=cls, flat=True)}
</g></g>"""
    glow_el = f'<ellipse cx="0" cy="30" rx="250" ry="150" fill="url(#{u}glow)"/>' if glow else ""
    c = ' class="os-body"' if cls else ""
    shine = (f'<rect class="os-shine" x="-60" y="-140" width="70" height="300" fill="url(#{u}shine)" '
             f'transform="rotate(18)" opacity="0"/>') if cls else ""
    return f"""<g transform="{t}">{glow_el}
  <ellipse cx="0" cy="124" rx="178" ry="21" fill="url(#{u}shadow)"/>
  <g{c}>
  {mouth_svg(u)}
  <path d="{BODY}" fill="url(#{u}body)"/>
  <g clip-path="url(#{u}clip)">
    <rect x="-230" y="-120" width="470" height="240" fill="url(#{u}belly)"/>
    <ellipse cx="200" cy="-10" rx="120" ry="110" fill="url(#{u}warm)"/>
    <rect x="-230" y="-120" width="470" height="240" fill="url(#{u}spec)"/>
    {shine}
  </g>
  <path d="{BODY}" fill="none" stroke="url(#{u}rim)" stroke-width="3" clip-path="url(#{u}clip)"/>
  {window_svg(C['hole'])}
  {holes_svg(cls=cls) if holes else ""}
  </g>
</g>"""


def waves_svg(u, p=PLACE, mode="gloss", cls=True):
    tx, ty = g2(*TIP, p=p)
    sc = p["s"] / PLACE["s"]
    stroke = {"mono": "currentColor", "flat": C["red"]}.get(mode, f"url(#{u}wave)")
    out = []
    for i, (r, w, op) in enumerate(WAVES):
        r2, w2 = r * sc, w * sc
        a0, a1 = math.radians(WAVE_A0), math.radians(WAVE_A1)
        x0, y0 = tx + r2 * math.cos(a0), ty + r2 * math.sin(a0)
        x1, y1 = tx + r2 * math.cos(a1), ty + r2 * math.sin(a1)
        c = f' class="os-wave os-w{i}" style="transform-origin:{f(tx)}px {f(ty)}px"' if cls else ""
        dash = ' pathLength="100" stroke-dasharray="100"' if cls else ""
        out.append(f'<path{c} d="M {f(x0)} {f(y0)} A {f(r2)} {f(r2)} 0 0 1 {f(x1)} {f(y1)}" fill="none" '
                   f'stroke="{stroke}" stroke-width="{f(w2)}" stroke-linecap="round" opacity="{op}"{dash}/>')
    return "".join(out)


def seal_svg(u, x, y, size, kind="prompt", mono=False, both=False, cls=True):
    """Hanko seal. kind: 'prompt' (❯_) or 'kanji' (殻). both=True stacks both for the flip animation."""
    s = size / 84.0
    ink = "#000" if mono else "#fff"
    cp, cc, ck = ((' class="os-seal-prompt"', ' class="os-cursor"', ' class="os-seal-kanji"') if cls else ("", "", ""))
    prompt = (f'<g{cp}><path d="M 21 25 L 39 42 L 21 59" fill="none" stroke="{ink}" stroke-width="8.5" '
              f'stroke-linecap="round" stroke-linejoin="round"/>'
              f'<rect{cc} x="45" y="53" width="20" height="8.5" rx="4.25" fill="{ink}"/></g>')
    kx = (84 - SEAL_KANJI["width"]) / 2
    kanji = f'<g{ck}><path d="{SEAL_KANJI["d"]}" fill="{ink}" transform="translate({f(kx)} 64)"/></g>'
    content = prompt + kanji if both else (prompt if kind == "prompt" else kanji)
    if mono:
        return f"""<g transform="translate({f(x)} {f(y)}) scale({f(s)})"><mask id="{u}sealmask" maskUnits="userSpaceOnUse" x="0" y="0" width="84" height="84">
  <rect width="84" height="84" fill="#fff"/>
  <rect x="5.5" y="5.5" width="73" height="73" rx="12.5" fill="none" stroke="#000" stroke-width="2.4"/>{content}</mask>
  <rect width="84" height="84" rx="17" fill="currentColor" mask="url(#{u}sealmask)"/></g>"""
    c = ' class="os-seal"' if cls else ""
    return f"""<g transform="translate({f(x)} {f(y)}) scale({f(s)})"><g{c} style="transform-origin:42px 42px">
  <rect width="84" height="84" rx="17" fill="url(#{u}seal)"/>
  <rect x="5.5" y="5.5" width="73" height="73" rx="12.5" fill="none" stroke="#fff" stroke-opacity=".92" stroke-width="2.4"/>
  {content}</g></g>"""


ANIM_CSS = """
<style>
/* OcarinaShell logo animation — intro ~1.5 s, then calm loops. Honors prefers-reduced-motion. */
.os-root { --os-e: cubic-bezier(.2,.9,.25,1.15); }
.os-float { animation: os-float 5.2s ease-in-out 1.6s infinite; }
.os-body { transform-box: fill-box; transform-origin: 50% 60%; animation: os-in .75s var(--os-e) both; }
.os-hole { transform-box: fill-box; transform-origin: center; animation: os-pop .42s var(--os-e) both, os-press 4.2s ease-in-out infinite; }
.os-h0 { animation-delay: .38s, 1.8s } .os-h1 { animation-delay: .44s, 2.25s } .os-h2 { animation-delay: .50s, 2.7s }
.os-h3 { animation-delay: .56s, 3.15s } .os-h4 { animation-delay: .62s, 3.75s } .os-h5 { animation-delay: .68s, 4.2s }
.os-wave { animation: os-draw .6s cubic-bezier(.3,.7,.2,1) both, os-pulse 2.4s ease-in-out infinite; }
.os-w0 { animation-delay: .78s, 1.7s } .os-w1 { animation-delay: .92s, 2.0s }
.os-shine { animation: os-shine 6.5s ease-in-out 2.2s infinite; }
.os-seal { animation: os-stamp .55s cubic-bezier(.3,1.5,.4,1) 1.12s both, os-flip 9s ease-in-out 3s infinite; }
.os-seal-kanji { animation: os-kanji 9s steps(1) 3s infinite; opacity: 0; }
.os-seal-prompt { animation: os-prompt 9s steps(1) 3s infinite; }
.os-cursor { animation: os-blink 1.1s steps(1) 1.7s infinite; }
.os-petal { transform-box: fill-box; transform-origin: center; animation: os-petal var(--d, 9s) linear var(--dl, 0s) infinite; opacity: 0; }
.os-letter { transform-box: fill-box; transform-origin: 50% 100%; animation: os-letter .6s var(--os-e) both; }
.os-kata { animation: os-fade 1s ease 1.5s both; }
@keyframes os-float { 0%,100% { transform: translateY(0) } 50% { transform: translateY(-7px) } }
@keyframes os-in { 0% { opacity: 0; transform: translateY(16px) scale(.86) } 100% { opacity: 1; transform: none } }
@keyframes os-pop { 0% { transform: scale(0) } 100% { transform: scale(1) } }
@keyframes os-press { 0%,100% { opacity: 1 } 5% { opacity: .3 } 10% { opacity: 1 } }
@keyframes os-draw { 0% { stroke-dashoffset: 100; opacity: 0 } 20% { opacity: 1 } 100% { stroke-dashoffset: 0 } }
@keyframes os-pulse { 0%,100% { transform: scale(1) } 50% { transform: scale(1.07) } }
@keyframes os-shine { 0% { opacity: 0; transform: rotate(18deg) translateX(-230px) } 4% { opacity: 1 } 22% { opacity: 1; transform: rotate(18deg) translateX(290px) } 23%,100% { opacity: 0; transform: rotate(18deg) translateX(290px) } }
@keyframes os-stamp { 0% { opacity: 0; transform: scale(1.7) rotate(-16deg) } 70% { opacity: 1; transform: scale(.93) rotate(2deg) } 100% { transform: none } }
@keyframes os-flip { 0%,44%,56%,100% { transform: scaleX(1) } 50% { transform: scaleX(0) } }
@keyframes os-kanji { 0% { opacity: 0 } 50% { opacity: 1 } 94.5% { opacity: 0 } }
@keyframes os-prompt { 0% { opacity: 1 } 50% { opacity: 0 } 94.5% { opacity: 1 } }
@keyframes os-blink { 0%,49% { opacity: 1 } 50%,100% { opacity: 0 } }
@keyframes os-letter { 0% { opacity: 0; transform: translateY(40px) skewX(-8deg) } 100% { opacity: 1; transform: none } }
@keyframes os-fade { from { opacity: 0 } to { opacity: 1 } }
@keyframes os-petal { 0% { opacity: 0; transform: translate(0,0) rotate(0deg) } 10% { opacity: .95 } 85% { opacity: .95 } 100% { opacity: 0; transform: translate(var(--tx,-260px), var(--ty,180px)) rotate(var(--r,320deg)) } }
@media (prefers-reduced-motion: reduce) { .os-root * { animation: none !important } .os-seal-kanji, .os-shine, .os-petal { opacity: 0 !important } }
</style>"""


def letters_svg(x0, base, ink, accent, animated, delay0=0.5, scale=1.0):
    """'Ocarina' + 'Shell'. Animated letters are wrapped so the CSS transform never overrides positioning."""
    out = [f'<g transform="translate({f(x0)} {f(base)}) scale({f(scale)})">']
    if animated:
        x = 0.0
        for i, lp in enumerate(LETTERS):
            col = accent if i >= 7 else ink
            out.append(f'<g transform="translate({f(x)} 0)"><path class="os-letter" style="animation-delay:{f(delay0 + i * .05)}s" '
                       f'd="{lp["d"]}" fill="{col}"/></g>')
            x += lp["width"] + (GAP if i == 6 else 0)
    else:
        out.append(f'<path d="{WORD_OC["d"]}" fill="{ink}"/>')
        out.append(f'<path d="{WORD_SH["d"]}" fill="{accent}" transform="translate({f(WORD_OC["width"] + GAP)} 0)"/>')
    out.append("</g>")
    return "".join(out)


WORD_W = WORD_OC["width"] + GAP + WORD_SH["width"]


# ----------------------------------------------------------------------------- compositions
def icon(u="i", seal="prompt", animated=False, mode="gloss"):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" class="os-root">', defs(u)]
    if animated:
        parts.append(ANIM_CSS)
    parts.append(f'<g clip-path="url(#{u}sq)"><rect width="512" height="512" fill="url(#{u}bg)"/>{seigaiha(u)}</g>')
    parts.append('<rect x=".75" y=".75" width="510.5" height="510.5" rx="113.5" fill="none" stroke="#000" stroke-opacity=".07" stroke-width="1.5"/>')
    fc = ' class="os-float"' if animated else ""
    parts.append(f'<g{fc}>{ocarina_svg(u, mode=mode, cls=animated)}{waves_svg(u, mode=mode, cls=animated)}</g>')
    if seal:
        parts.append(seal_svg(u, 386, 386, 86, kind=seal, both=animated, cls=animated))
    parts.append("</svg>")
    return "".join(parts)


def mark(u="m", mode="gloss", animated=False):
    """Ocarina + waves only, transparent background, tight viewBox (bar, inline use)."""
    p = MARK_PLACE
    # 270 high (not 250) so the soft contact shadow of the gloss mark is never cut off
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{MARK_BOX[0]} {MARK_BOX[1]} {MARK_BOX[2]} {MARK_BOX[3]}" class="os-root">',
             defs(u, mono=(mode == "mono"))]
    if animated:
        parts.append(ANIM_CSS)
    fc = ' class="os-float"' if animated else ""
    parts.append(f'<g{fc}>{ocarina_svg(u, p, mode=mode, glow=False, cls=animated)}{waves_svg(u, p, mode=mode, cls=animated)}</g>')
    parts.append("</svg>")
    return "".join(parts)


def wordmark(u="w", bg="light", animated=False):
    """Horizontal lockup: mark + Ocarina|Shell + katakana + small seal. bg: light | dark | mono."""
    mono = bg == "mono"
    ink = "currentColor" if mono else (C["inkDark"] if bg == "light" else C["inkLight"])
    accent = "currentColor" if mono else C["red"]
    muted = "currentColor" if mono else (C["mutedDark"] if bg == "light" else C["mutedLight"])
    p = {"cx": 205, "cy": 205, "s": 0.74, "rot": -14}
    tx0, base = 470, 238
    W, H = tx0 + WORD_W + 120, 400
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(W)} {H}" class="os-root">', defs(u, mono=mono)]
    if animated:
        parts.append(ANIM_CSS)
    mode = "mono" if mono else "gloss"
    fc = ' class="os-float"' if animated else ""
    parts.append(f'<g{fc}>{ocarina_svg(u, p, mode=mode, glow=False, cls=animated)}{waves_svg(u, p, mode=mode, cls=animated)}</g>')
    parts.append(letters_svg(tx0, base, ink, accent, animated))
    kc = ' class="os-kata"' if animated else ""
    parts.append(f'<path{kc} d="{KATA["d"]}" fill="{muted}" transform="translate({tx0 + 6} {base + 84})"/>')
    seal_x = tx0 + WORD_W + 22
    parts.append(f'<g transform="rotate(6 {f(seal_x + 31)} {base - 119})">'
                 + seal_svg(u, seal_x, base - 150, 62, kind="prompt", mono=mono, both=animated, cls=animated) + "</g>")
    parts.append("</svg>")
    return "".join(parts), W, H


def hero(u="h", bg="dark"):
    """Big animated vertical lockup (lock screen / about / greeter) with drifting petals."""
    W, H = 1200, 900
    ink = C["inkLight"] if bg == "dark" else C["inkDark"]
    muted = C["mutedLight"] if bg == "dark" else C["mutedDark"]
    p = {"cx": 590, "cy": 330, "s": 1.2, "rot": -14}
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" class="os-root">', defs(u), ANIM_CSS]
    petals = [(880, 110, 1.6, 20, "11s", "0s", "-430px", "560px", "380deg"),
              (1000, 210, 1.2, -30, "13s", "2.5s", "-520px", "470px", "300deg"),
              (780, 50, 1.0, 60, "12s", "5s", "-380px", "620px", "420deg"),
              (1090, 330, 1.4, 10, "14s", "7.5s", "-600px", "420px", "340deg"),
              (940, 0, 1.1, -50, "10s", "4s", "-300px", "700px", "280deg")]
    for (x, y, s, r, d, dl, txx, tyy, rr) in petals:
        parts.append(f'<g transform="translate({x} {y}) rotate({r}) scale({s * 1.5})"><g class="os-petal" '
                     f'style="--d:{d};--dl:{dl};--tx:{txx};--ty:{tyy};--r:{rr}"><path d="{PETAL}" fill="{C["petal"]}"/></g></g>')
    parts.append(f'<g class="os-float">{ocarina_svg(u, p, cls=True)}{waves_svg(u, p, cls=True)}</g>')
    sc = 0.66
    x = (W - WORD_W * sc) / 2 - 30
    base = 690
    parts.append(letters_svg(x, base, ink, C["red"], True, delay0=.55, scale=sc))
    kx = (W - KATA["width"]) / 2 - 30
    parts.append(f'<path class="os-kata" d="{KATA["d"]}" fill="{muted}" transform="translate({f(kx)} {base + 74})"/>')
    sx = x + WORD_W * sc + 20
    parts.append(f'<g transform="rotate(6 {f(sx + 30)} {base - 92})">' + seal_svg(u, sx, base - 122, 60, both=True) + "</g>")
    parts.append("</svg>")
    return "".join(parts), W, H


def seal_only(u, kind, mono=False):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 84 84">{"" if mono else defs(u)}'
            f'{seal_svg(u, 0, 0, 84, kind=kind, mono=mono, cls=False)}</svg>')


# ----------------------------------------------------------------------------- write files
def main(out):
    OUT = pathlib.Path(out)
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "ocarinashell-icon.svg": icon("i", seal="prompt"),
        "ocarinashell-icon-kanji.svg": icon("k", seal="kanji"),
        "ocarinashell-icon-noseal.svg": icon("n", seal=None),
        "ocarinashell-icon-flat.svg": icon("fl", seal="prompt", mode="flat"),
        "ocarinashell-icon-animated.svg": icon("a", seal="prompt", animated=True),
        "ocarinashell-mark.svg": mark("m"),
        "ocarinashell-mark-flat.svg": mark("mf", mode="flat"),
        "ocarinashell-mark-mono.svg": mark("mm", mode="mono"),
        "ocarinashell-mark-animated.svg": mark("ma", animated=True),
    }
    for key in ("light", "dark", "mono"):
        files[f"ocarinashell-wordmark-{key}.svg"] = wordmark("w" + key[0], bg=key)[0]
    files["ocarinashell-wordmark-animated-light.svg"] = wordmark("wal", bg="light", animated=True)[0]
    files["ocarinashell-wordmark-animated-dark.svg"] = wordmark("wad", bg="dark", animated=True)[0]
    files["ocarinashell-hero-animated-dark.svg"] = hero("hd", "dark")[0]
    files["ocarinashell-hero-animated-light.svg"] = hero("hl", "light")[0]
    files["ocarinashell-seal.svg"] = seal_only("s", "prompt")
    files["ocarinashell-seal-kanji.svg"] = seal_only("sk", "kanji")
    files["ocarinashell-seal-mono.svg"] = seal_only("sm", "prompt", mono=True)
    for name, svg in files.items():
        (OUT / name).write_text(svg)

    geo = {
        "comment": "OcarinaShell logo geometry (red on white). Local ocarina space: place with translate(cx,cy) rotate(rot) scale(s). "
                   "Generated by tools/logo_gen.py — do not edit by hand.",
        "colors": C,
        "body": BODY, "mouth": MOUTH, "window": WINDOW,
        "holes": [{"x": x, "y": y, "r": r} for x, y, r in HOLES],
        "tip": {"x": TIP[0], "y": TIP[1]},
        "waves": [{"r": r, "width": w, "opacity": o} for r, w, o in WAVES],
        "waveAngles": [WAVE_A0, WAVE_A1],
        "iconPlacement": PLACE,
        "markPlacement": MARK_PLACE, "markViewBox": list(MARK_BOX),
        "petal": PETAL,
        "seal": {"size": 84, "radius": 17, "innerInset": 5.5, "innerRadius": 12.5,
                 "prompt": {"chevron": "M 21 25 L 39 42 L 21 59", "stroke": 8.5, "cursor": {"x": 45, "y": 53, "w": 20, "h": 8.5}},
                 "kanjiPath": SEAL_KANJI["d"], "kanjiOffset": [round((84 - SEAL_KANJI["width"]) / 2, 2), 64]},
        "wordmark": {"font": "Unbounded wght 600", "size": 150, "gap": GAP,
                     "Ocarina": WORD_OC["d"], "OcarinaWidth": WORD_OC["width"],
                     "Shell": WORD_SH["d"], "ShellWidth": WORD_SH["width"],
                     "katakana": KATA["d"], "katakanaWidth": KATA["width"],
                     "katakanaFont": "Zen Kaku Gothic New Medium 44px, tracking .32em"},
    }
    geo_dir = OUT.parent if OUT.name == "svg" else OUT
    (geo_dir / "logo-geometry.json").write_text(json.dumps(geo, ensure_ascii=False, indent=1))
    print("wrote", len(files), "svgs to", OUT)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else K / "assets" / "logo" / "svg")
