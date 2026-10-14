#!/usr/bin/env python3
"""Procedural wallpapers, one per theme (2880×1800, the P14s OLED panel) -> assets/wallpapers/*.jpg

All art is original and generated here (numpy + Pillow): no third-party images.
  kurenai-yoru    red moon over ink mountains (Kurenai)
  kohaku-washi    washi paper, red sun and editorial hairlines (Kōhaku)
  sumi-sansui     ink-wash mountains in mist (Sumi)
  ai-seigaiha     indigo seigaiha waves turning gold (Ai)
  matcha-asanoha  kinari paper with an asanoha pattern (Matcha)
  yozakura        night cherry branch in bloom (Yozakura)
Each carries the ❯_ hanko in the lower-right corner. JPEG q95 4:4:4 (grain makes PNG ~10 MB each).

usage: python3 tools/wallpapers.py [name …] [/output/dir] [--preview]
"""
import math
import os
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

K = pathlib.Path(__file__).resolve().parent.parent
W, H = 2880, 1800
FONT_DIRS = [pathlib.Path(p).expanduser() for p in
             os.environ.get("OCARINA_FONTS", "~/.local/share/fonts/ocarinashell:~/.local/share/fonts:/usr/share/fonts").split(":")]


def font(prefix, size):
    for d in FONT_DIRS:
        if d.is_dir():
            for f in sorted(d.rglob(f"{prefix}*")):
                if f.suffix.lower() in (".ttf", ".otf"):
                    return ImageFont.truetype(str(f), size)
    return None


# ----------------------------------------------------------------------------- helpers (float RGB arrays 0..255)
def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def grid():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    return x, y


def vnoise(cells_x, cells_y, rng, w=W, h=H):
    small = rng.random((cells_y + 1, cells_x + 1)).astype(np.float32)
    return np.asarray(Image.fromarray(small, mode="F").resize((w, h), Image.BICUBIC), np.float32)


def fbm(cells, octaves, rng, gain=0.5, w=W, h=H):
    out, amp, tot = np.zeros((h, w), np.float32), 1.0, 0.0
    for o in range(octaves):
        c = cells * 2 ** o
        out += amp * vnoise(c, max(1, int(c * h / w)), rng, w, h)
        tot += amp
        amp *= gain
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def noise1d(n, cells, rng):
    pts = rng.random(cells + 2)
    x = np.linspace(0, cells, n)
    i = np.floor(x).astype(int)
    f = x - i
    f = (1 - np.cos(f * np.pi)) / 2
    return pts[i] * (1 - f) + pts[i + 1] * f


def fbm1d(n, cells, octaves, rng, gain=0.5):
    s, a, t = np.zeros(n), 1.0, 0.0
    for o in range(octaves):
        s += a * noise1d(n, cells * 2 ** o, rng)
        t += a
        a *= gain
    return s / t


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def vgrad(top, bottom, curve=1.0):
    t = (np.linspace(0, 1, H, dtype=np.float32) ** curve)[:, None, None]
    return np.broadcast_to(hexc(top) * (1 - t) + hexc(bottom) * t, (H, W, 3)).copy()


def disc_alpha(x, y, cx, cy, r):
    return np.clip(r - np.hypot(x - cx, y - cy) + 0.5, 0, 1)


def ridge_profile(rng, peaks, hmin, hmax, wmin, wmax, rough, cells=6, shape="cone", power=(1.0, 1.5), base_range=0.0):
    """Distinct peaks + fractal roughness (0 = foot). shape: cone (ranges) | tower (karst peaks of 山水画).
    base_range > 0 adds a continuous low range underneath (fraction of hmax) so towers never stand on a flat plain."""
    xs = np.arange(W, dtype=np.float32)
    prof = np.zeros(W, np.float32)
    for _ in range(peaks):
        c = rng.uniform(-0.1, 1.1) * W
        h = rng.uniform(hmin, hmax)
        wl = rng.uniform(wmin, wmax) * W
        wr = wl * rng.uniform(0.6, 1.5)
        d = np.where(xs < c, (c - xs) / wl, (xs - c) / wr)
        if shape == "tower":
            f = np.clip(1 - d * d, 0, 1) ** rng.uniform(0.45, 0.7)
        else:
            f = np.clip(1 - d, 0, 1) ** rng.uniform(*power)
        prof = np.maximum(prof, h * f)
    if base_range:
        rngx = fbm1d(W, 3, 6, rng, 0.55)
        prof = np.maximum(prof, base_range * hmax * (0.35 + 0.65 * (rngx - rngx.min()) / (np.ptp(rngx) + 1e-6)))
    detail = fbm1d(W, cells, 7, rng, 0.58) - 0.5
    return prof + rough * detail * (0.35 + prof / (prof.max() + 1e-6))


def mountains(img, x, y, rng, base, prof, color, mist, fade, mist_amt=0.85):
    """One ridge layer: ink colour at the crest fading into mist towards its foot."""
    crest = base - prof
    d = y - crest[None, :]
    a = np.clip(d / 1.4 + 0.5, 0, 1)
    m = mist_amt * (1 - np.exp(-np.maximum(d, 0) / fade))
    col = mix(np.broadcast_to(hexc(color), img.shape), np.broadcast_to(hexc(mist), img.shape), m)
    return mix(img, col, a)


def grain(img, rng, amt):
    return img + rng.normal(0, amt, (H, W, 1)).astype(np.float32)


def vignette(img, x, y, amt=0.35, power=2.2):
    d = np.hypot((x - W / 2) / (W / 2), (y - H / 2) / (H / 2)) / math.sqrt(2)
    return img * (1 - amt * d ** power)[..., None]


def hanko(im, x, y, size=92, angle=-4, color0="#ef1d3c", color1="#b3001e", ink="#ffffff"):
    """The ❯_ seal (same geometry as the logo, 84-unit box), drawn at 4× and pasted with alpha."""
    S = 4
    n = int(84 * S)
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    g = np.linspace(0, 1, n, dtype=np.float32)
    t = (g[None, :] + g[:, None]) / 2
    rgb = (hexc(color0) * (1 - t[..., None]) + hexc(color1) * t[..., None]).astype(np.uint8)
    grad = Image.fromarray(rgb, "RGB").convert("RGBA")
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, n - 1), radius=17 * S, fill=255)
    layer.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(layer)
    inkc = tuple(int(v) for v in hexc(ink)) + (235,)
    d.rounded_rectangle((5.5 * S - 1.2 * S, 5.5 * S - 1.2 * S, 78.5 * S + 1.2 * S, 78.5 * S + 1.2 * S),
                        radius=13.7 * S, outline=inkc, width=int(2.4 * S))
    w8 = int(8.5 * S)
    pts = [(21 * S, 25 * S), (39 * S, 42 * S), (21 * S, 59 * S)]
    d.line(pts, fill=inkc[:3] + (255,), width=w8, joint="curve")
    for px, py in (pts[0], pts[2]):
        d.ellipse((px - w8 / 2, py - w8 / 2, px + w8 / 2, py + w8 / 2), fill=inkc[:3] + (255,))
    d.rounded_rectangle((45 * S, 53 * S, 65 * S, 61.5 * S), radius=4.25 * S, fill=inkc[:3] + (255,))
    layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    k = size / 84
    layer = layer.resize((int(layer.width * k / S), int(layer.height * k / S)), Image.LANCZOS)
    im.alpha_composite(layer, (int(x), int(y)))


def finish(img, name, out, seal=True, seal_kw=None):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    if seal:
        hanko(im, W - 150, H - 150, **(seal_kw or {}))
    path = pathlib.Path(out) / f"{name}.jpg"
    im.convert("RGB").save(path, quality=95, subsampling=0, optimize=True)
    print(f"{path.name:22s} {path.stat().st_size // 1024} KB")
    return path


# ----------------------------------------------------------------------------- 1 · 紅夜 kurenai-yoru
def kurenai_yoru(out):
    rng = np.random.default_rng(7)
    x, y = grid()
    img = vgrad("#0a090b", "#1c0a0f", 1.6)
    mx, my, mr = W * 0.665, H * 0.36, H * 0.135
    d = np.hypot(x - mx, y - my)
    img += hexc("#e60033") * (0.42 * np.exp(-np.maximum(d - mr, 0) / (H * 0.16)))[..., None] * 0.55
    img += hexc("#e60033") * (0.10 * np.exp(-d / (H * 0.6)))[..., None]
    tex = fbm(5, 5, rng)
    moon = mix(hexc("#ff2d52"), hexc("#b8002a"), np.clip((d / mr) ** 2.2, 0, 1)) * (0.9 + 0.1 * tex)[..., None]
    img = mix(img, moon, disc_alpha(x, y, mx, my, mr))
    for cx, cy, a, b, s in ((mx - 120, my + 70, 520, 15, 0.9), (mx + 160, my + 118, 380, 10, 0.8), (mx - 400, my + 168, 640, 12, 0.6)):
        streak = s * np.exp(-((x - cx) / a) ** 2 - ((y - cy) / b) ** 2)
        img = mix(img, np.broadcast_to(hexc("#0b090b"), img.shape), streak)
    img = mountains(img, x, y, rng, H * 0.80, ridge_profile(rng, 6, H * .10, H * .26, .16, .30, 46), "#2c0e16", "#5a1424", 230, 0.8)
    img = mountains(img, x, y, rng, H * 0.88, ridge_profile(rng, 7, H * .07, H * .19, .12, .24, 38), "#170a0e", "#3a0f19", 200, 0.7)
    img = mountains(img, x, y, rng, H * 1.0, ridge_profile(rng, 8, H * .05, H * .13, .10, .20, 30), "#060405", "#14080b", 260, 0.5)
    img = vignette(img, x, y, 0.38)
    return finish(grain(img, rng, 2.2), "kurenai-yoru", out)


# ----------------------------------------------------------------------------- 2 · 紅白 kohaku-washi
def fibers(rng, n, light, dark):
    layer = Image.new("L", (W, H), 128)
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x0, y0 = rng.random() * W, rng.random() * H
        ang = rng.random() * math.pi * 2
        ln = 18 + rng.random() * 140
        curv = (rng.random() - 0.5) * 0.04
        pts = []
        for k in range(12):
            pts.append((x0, y0))
            ang += curv
            x0 += math.cos(ang) * ln / 12
            y0 += math.sin(ang) * ln / 12
        v = 128 + (light if rng.random() < 0.6 else -dark) * (0.4 + 0.6 * rng.random())
        d.line(pts, fill=int(v), width=1 if rng.random() < 0.8 else 2)
    return (np.asarray(layer.filter(ImageFilter.GaussianBlur(0.6)), np.float32) - 128) / 128


def kohaku_washi(out):
    rng = np.random.default_rng(11)
    x, y = grid()
    paper = fbm(4, 6, rng)
    img = np.broadcast_to(hexc("#f4f1ec"), (H, W, 3)).copy()
    img += ((paper - 0.5) * 9)[..., None]
    img += (fibers(rng, 2600, 60, 40) * 9)[..., None]
    sx, sy, sr = W * 0.315, H * 0.445, H * 0.175
    dd = np.hypot(x - sx, y - sy)
    a = np.clip(sr - dd + 0.6, 0, 1)
    bleed = np.clip(1 - (dd - sr) / 7, 0, 1) * (dd > sr) * (0.10 + 0.12 * fibers(rng, 900, 90, 0) .clip(0, 1))
    img = mix(img, np.broadcast_to(hexc("#e60033"), img.shape), bleed)
    sun = mix(hexc("#ef0a3c"), hexc("#d0002e"), np.clip((y - (sy - sr)) / (2 * sr), 0, 1) ** 1.5)
    sun = sun * (0.955 + 0.045 * paper)[..., None]
    img = mix(img, sun, a * 0.97)
    im = Image.fromarray(np.clip(grain(img, rng, 1.2), 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")
    y0 = int(H * 0.62)
    d.line((int(W * 0.40), y0, int(W * 0.935), y0), fill=(24, 23, 28, 150), width=2)
    d.line((int(W * 0.40), y0 + 14, int(W * 0.40) + 190, y0 + 14), fill=(230, 0, 51, 255), width=3)
    xv = int(W * 0.858)
    d.line((xv, int(H * 0.16), xv, int(H * 0.585)), fill=(24, 23, 28, 90), width=2)
    f = font("ShipporiMinchoB1-Medium", 66)
    fk = font("ZenKakuGothicNew-Regular", 22)
    if f:
        for i, ch in enumerate("紅白"):
            d.text((xv + 34, int(H * 0.17) + i * 84), ch, font=f, fill=(24, 23, 28, 230))
    if fk:
        for i, ch in enumerate("こうはく"):
            d.text((xv + 116, int(H * 0.175) + i * 30), ch, font=fk, fill=(97, 91, 85, 200))
        d.text((int(W * 0.40), y0 + 34), "OCARINASHELL · 紅白", font=fk, fill=(97, 91, 85, 190))
    return finish(np.asarray(im, np.float32), "kohaku-washi", out)


# ----------------------------------------------------------------------------- 3 · 墨 sumi-sansui
def sumi_sansui(out):
    rng = np.random.default_rng(23)
    x, y = grid()
    img = vgrad("#0c0c0d", "#1d1d1f", 1.2)
    mx, my, mr = W * 0.23, H * 0.25, H * 0.055
    d = np.hypot(x - mx, y - my)
    img += hexc("#d9d4ca") * (0.10 * np.exp(-np.maximum(d - mr, 0) / (H * 0.12)))[..., None]
    img = mix(img, np.broadcast_to(hexc("#d9d4ca"), img.shape), disc_alpha(x, y, mx, my, mr) * 0.82)
    for base, peaks, hmin, hmax, wmin, wmax, col, mist, fade, ma in (
            (0.66, 9, .12, .30, .09, .18, "#4a4a4f", "#28282c", 170, 0.92), (0.77, 9, .09, .22, .09, .18, "#313136", "#222226", 180, 0.9),
            (0.89, 9, .06, .15, .10, .20, "#1a1a1d", "#1d1d20", 200, 0.85), (1.0, 8, .05, .11, .10, .20, "#08080a", "#121214", 230, 0.6)):
        img = mountains(img, x, y, rng, H * base, ridge_profile(rng, peaks, H * hmin, H * hmax, wmin, wmax, 30,
                                                                 power=(1.1, 1.6)), col, mist, fade, ma)
    fog = fbm(3, 4, rng)
    band = np.exp(-((y - H * 0.80) / (H * 0.07)) ** 2) * (0.25 + 0.4 * fog)
    img = mix(img, np.broadcast_to(hexc("#2c2c30"), img.shape), band * 0.6)
    img = vignette(img, x, y, 0.32)
    return finish(grain(img, rng, 2.6), "sumi-sansui", out)


# ----------------------------------------------------------------------------- 4 · 藍 ai-seigaiha
def ai_seigaiha(out):
    rng = np.random.default_rng(31)
    x, y = grid()
    t = np.clip((x / W * 0.7 + y / H * 0.7 - 0.6) / 0.6, 0, 1) ** 1.4
    img = mix(np.broadcast_to(hexc("#0f1a3a"), (H, W, 3)), np.broadcast_to(hexc("#050915"), (H, W, 3)),
              np.clip(x / W * 0.45 + y / H * 0.55, 0, 1))
    S, R = 2, 76
    mask = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(mask)
    row, cy = 0, -R
    while cy < H + R:
        cx = -(R if row % 2 else 0)
        while cx < W + 2 * R:
            X, Y, RR = cx * S, cy * S, R * S
            d.ellipse((X - RR, Y - RR, X + RR, Y + RR), fill=0)
            for k in (1.0, 0.74, 0.48, 0.22):
                r = (R * k - 3) * S
                d.ellipse((X - r, Y - r, X + r, Y + r), outline=255, width=int(2.6 * S))
            cx += 2 * R
        cy += R / 2
        row += 1
    m = np.asarray(mask.resize((W, H), Image.LANCZOS), np.float32) / 255
    line = mix(np.broadcast_to(hexc("#30488f"), (H, W, 3)), np.broadcast_to(hexc("#e6b422"), (H, W, 3)), t * 0.9)
    alpha = m * (0.42 + 0.5 * t)
    img = mix(img, line, alpha)
    glow = np.exp(-np.hypot(x - W * 0.86, y - H * 0.9) / (H * 0.5))
    img += (hexc("#e6b422") * 0.06)[None, None, :] * glow[..., None]
    img = vignette(img, x, y, 0.4)
    return finish(grain(img, rng, 1.8), "ai-seigaiha", out)


# ----------------------------------------------------------------------------- 5 · 抹茶 matcha-asanoha
def matcha_asanoha(out):
    rng = np.random.default_rng(41)
    x, y = grid()
    paper = fbm(4, 6, rng)
    img = np.broadcast_to(hexc("#f3f1e7"), (H, W, 3)).copy() + ((paper - 0.5) * 8)[..., None]
    img += (fibers(rng, 1800, 50, 30) * 7)[..., None]
    t = np.clip((x / W * 0.7 + y / H * 0.7 - 0.6) / 0.6, 0, 1) ** 1.4
    S, a = 2, 120.0                                   # triangle side
    hgt = a * math.sqrt(3) / 2
    mask = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(mask)
    lw = int(1.6 * S)
    rows = int(H / hgt) + 2
    cols = int(W / a) + 3
    for j in range(-1, rows):
        for i in range(-2, cols):
            ox = i * a + (a / 2 if j % 2 else 0)
            oy = j * hgt
            for tri in (((ox, oy), (ox + a, oy), (ox + a / 2, oy + hgt)),
                        ((ox + a, oy), (ox + a / 2, oy + hgt), (ox + 1.5 * a, oy + hgt))):
                cx = sum(p[0] for p in tri) / 3
                cy = sum(p[1] for p in tri) / 3
                P = [(px * S, py * S) for px, py in tri]
                d.line(P + [P[0]], fill=255, width=lw)
                for px, py in P:
                    d.line((px, py, cx * S, cy * S), fill=255, width=lw)
    m = np.asarray(mask.resize((W, H), Image.LANCZOS), np.float32) / 255
    line = mix(np.broadcast_to(hexc("#a9b56a"), (H, W, 3)), np.broadcast_to(hexc("#5d7a16"), (H, W, 3)), t)
    img = mix(img, line, m * (0.16 + 0.46 * t))
    wash = np.exp(-np.hypot(x - W * 0.2, y - H * 0.25) / (H * 0.55))
    img = mix(img, np.broadcast_to(hexc("#fbfaf5"), img.shape), wash * 0.55)
    tea = np.exp(-np.hypot(x - W * 1.02, y - H * 1.05) / (H * 0.42))
    img = mix(img, np.broadcast_to(hexc("#b9c27a"), img.shape), tea * 0.38)
    return finish(grain(img, rng, 1.1), "matcha-asanoha", out)


# ----------------------------------------------------------------------------- 6 · 夜桜 yozakura
def yozakura(out):
    rng_np = np.random.default_rng(42)
    import random
    rng = random.Random(42)
    x, y = grid()
    img = vgrad("#1b1130", "#0b0810", 1.1)
    glow = np.exp(-np.hypot(x - W * 0.82, y - H * 0.1) / (H * 0.7))
    img += hexc("#f0708f")[None, None, :] * (0.10 * glow)[..., None]
    stars = (rng_np.random((H, W)) > 0.99965) * rng_np.random((H, W)) * 150
    img += (stars * (1 - y / H))[..., None]
    mx, my, mr = W * 0.16, H * 0.2, H * 0.05
    img = mix(img, np.broadcast_to(hexc("#f6e9ef"), img.shape), disc_alpha(x, y, mx, my, mr) * 0.9)
    img += hexc("#f6e9ef") * (0.08 * np.exp(-np.maximum(np.hypot(x - mx, y - my) - mr, 0) / (H * 0.1)))[..., None]
    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    S = 2
    wood = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    bloom = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    dw, db = ImageDraw.Draw(wood), ImageDraw.Draw(bloom)
    petals = [(246, 193, 207), (240, 160, 181), (252, 222, 230), (236, 130, 160)]

    def flower(cx, cy, r, rot):
        col = petals[rng.randrange(len(petals))]
        for k in range(5):
            a = rot + k * 2 * math.pi / 5
            px, py = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
            pr = r * 0.52
            db.ellipse((px - pr, py - pr, px + pr, py + pr), fill=col + (235,))
        db.ellipse((cx - r * 0.22, cy - r * 0.22, cx + r * 0.22, cy + r * 0.22), fill=(255, 240, 244, 255))
        db.ellipse((cx - r * 0.09, cy - r * 0.09, cx + r * 0.09, cy + r * 0.09), fill=(200, 60, 100, 255))

    def seg(px, py, nx, ny, w, nw):
        for (ox, oy, col, k) in ((-0.22, -0.22, (58, 42, 74, 255), 1.0), (0.12, 0.12, (9, 6, 12, 255), 0.84)):
            ww = max(1.0, w * k)
            dw.line(((px + ox * w) * S, (py + oy * w) * S, (nx + ox * w) * S, (ny + oy * w) * S), fill=col, width=int(ww * S))
            r = max(0.5, nw * k / 2)
            dw.ellipse(((nx + ox * w - r) * S, (ny + oy * w - r) * S, (nx + ox * w + r) * S, (ny + oy * w + r) * S), fill=col)

    def grow(x0, y0, ang, length, width, depth):
        if depth == 0 or length < 16:
            return
        steps = max(5, int(length / 26))
        px, py, w = x0, y0, width
        for k in range(steps):
            ang += rng.uniform(-0.26, 0.26) + (TARGET - ang) * 0.045
            nx, ny = px + math.cos(ang) * length / steps, py + math.sin(ang) * length / steps
            nw = max(1.6, w * 0.965)
            seg(px, py, nx, ny, w, nw)
            if depth <= 4 and rng.random() < (0.30 if depth <= 2 else 0.10):
                for _ in range(rng.randint(1, 3)):
                    fx, fy = nx + rng.gauss(0, 18), ny + rng.gauss(0, 18)
                    flower(fx * S, fy * S, rng.uniform(9, 22) * S, rng.random() * 6.3)
            if depth <= 5 and rng.random() < 0.10:     # short twig
                ta = ang + rng.choice((-1, 1)) * rng.uniform(0.6, 1.1)
                grow(nx, ny, ta, length * 0.28, max(1.6, nw * 0.45), min(depth - 1, 2))
            px, py, w = nx, ny, nw
        kids = 2 if rng.random() < 0.8 else 3
        for k in range(kids):
            da = rng.uniform(0.22, 0.62) * (1 if k % 2 else -1)
            grow(px, py, ang + da, length * rng.uniform(0.66, 0.8), w * rng.uniform(0.66, 0.78), depth - 1)

    TARGET = math.radians(176)          # grow towards the moon (left), not down the edge
    grow(W + 60, H * 0.02, math.radians(158), 640, 50, 6)
    for _ in range(70):                                    # falling petals
        fx, fy = rng.uniform(0.05, 0.85) * W, rng.uniform(0.3, 0.98) * H
        r = rng.uniform(5, 11)
        a = rng.random() * 6.3
        pts = [(fx + math.cos(a + t) * r * (1.0 if t in (0, math.pi) else 0.45),
                fy + math.sin(a + t) * r * (1.0 if t in (0, math.pi) else 0.45)) for t in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
        db.polygon([(px * S, py * S) for px, py in pts], fill=petals[rng.randrange(4)] + (rng.randint(110, 200),))
    wood = wood.resize((W, H), Image.LANCZOS)
    bloom = bloom.resize((W, H), Image.LANCZOS)
    halo = bloom.filter(ImageFilter.GaussianBlur(26))
    halo.putalpha(halo.getchannel("A").point(lambda v: int(v * 0.55)))
    base.alpha_composite(wood)
    base.alpha_composite(halo)
    base.alpha_composite(bloom)
    img = np.asarray(base.convert("RGB"), np.float32)
    img = vignette(img, x, y, 0.35)
    return finish(grain(img, rng_np, 2.0), "yozakura", out)


ALL = {"kurenai-yoru": kurenai_yoru, "kohaku-washi": kohaku_washi, "sumi-sansui": sumi_sansui,
       "ai-seigaiha": ai_seigaiha, "matcha-asanoha": matcha_asanoha, "yozakura": yozakura}


def preview(paths, out):
    tw, th_ = 640, 400
    sheet = Image.new("RGB", (3 * tw + 40, 2 * th_ + 30), (40, 38, 42))
    for i, p in enumerate(paths):
        im = Image.open(p).resize((tw, th_), Image.LANCZOS)
        sheet.paste(im, (10 + (i % 3) * (tw + 10), 10 + (i // 3) * (th_ + 10)))
    path = pathlib.Path(out) / "preview" / "preview.jpg"     # own folder: `*.jpg` in out/ are only wallpapers
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, quality=88)
    print("preview:", path)


def main(argv):
    out = next((a for a in argv if a.startswith("/")), str(K / "assets" / "wallpapers"))
    names = [a for a in argv if not a.startswith("/") and not a.startswith("--")] or list(ALL)
    pathlib.Path(out).mkdir(parents=True, exist_ok=True)
    paths = [ALL[n](out) for n in names]
    if "--preview" in argv:
        preview(paths, out)


if __name__ == "__main__":
    main(sys.argv[1:])
