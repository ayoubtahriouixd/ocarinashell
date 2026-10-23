#!/usr/bin/env python3
"""Boot chain assets, sharing the logo geometry of tools/logo_gen.py:

  assets/boot/limine/ocarinashell-limine-{dark,light}.png   Limine wallpapers (2880×1800, menu card in the middle)
  assets/boot/limine/limine-tema-{dark,light}.conf          block for the top of limine.conf (Limine 10.x)
  assets/boot/limine/limine-test-{dark,light}.conf          same + sample entries + `timeout: no` (QEMU previews)
  assets/boot/plymouth/ocarinashell/                        Plymouth script theme: .plymouth, .script, layers
  assets/boot/plymouth/preview-*.png                        captures of the theme running in a real plymouthd 24.004.60
                                                            (x11 renderer under Xvfb, 2880×1800); --previews composites
                                                            equivalent images with Pillow instead
  assets/boot/src/*.html                                    sources of every rendered image

Plymouth layers share one 760×760 canvas (drawn at 380 px on a 1800 px tall screen: centre at 50 % / 42 %), so the
greeter and the in-session farewell can put the icon in exactly the same place.
usage: OCARINA_FONTS=<dir> python3 tools/boot_assets.py [--fonts DIR]      (needs Chromium; see htmlshot.py)
"""
import argparse
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import logo_gen as L  # noqa: E402
from htmlshot import browser  # noqa: E402
from mockups import font_css  # noqa: E402

K = pathlib.Path(__file__).resolve().parent.parent
OUT = K / "assets/boot"
LIM, PLY, SRC = OUT / "limine", OUT / "plymouth", OUT / "src"
THEME = PLY / "ocarinashell"
W, H = 2880, 1800
LAYER = 760                       # layer canvas (2× the 380 px drawn at 1800p)
ICON_PX = 380                     # icon size on a 1800 px tall screen
CY_FRAC = 0.42                    # icon centre (fraction of the height) — same in greeter and farewell
VAR = {
    "dark": dict(bg="#0b0a0c", ink="#f4efe6", muted="#8a847d", line="rgba(255,255,255,.09)", card="rgba(255,255,255,.035)",
                 pattern="#e60033", rgb=(11, 10, 12)),
    "light": dict(bg="#f4f1ec", ink="#18171c", muted="#615b55", line="rgba(24,23,28,.10)", card="rgba(255,255,255,.72)",
                  pattern="#e60033", rgb=(244, 241, 236)),
}
MESSAGES = {  # id: (japanese, spanish)
    "boot": ("ようこそ", "Bienvenido"),
    "shutdown": ("おやすみなさい", "Apagando"),
    "reboot": ("また後で", "Reiniciando"),
    "update": ("更新中", "Actualizando · no apagues el equipo"),
    "firmware": ("更新中", "Actualizando el firmware · no apagues el equipo"),
}


# ----------------------------------------------------------------------------- helpers
def page(body, w, h, bg="transparent", extra_css=""):
    return (f'<!doctype html><html lang="es"><head><meta charset="utf-8"><style>html,body{{margin:0;width:{w}px;height:{h}px;'
            f'background:{bg};overflow:hidden}} *{{box-sizing:border-box}} {extra_css}</style></head><body>{body}</body></html>')


def render(b, name, html, w, h, out, fcss, transparent=True):
    (SRC / f"{name}.html").write_text(html)
    pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
    pg.goto((SRC / f"{name}.html").as_uri(), wait_until="load")
    if fcss:
        pg.add_style_tag(content=fcss)
    pg.evaluate("Promise.all([...document.fonts].map(f => f.load().catch(() => 0))).then(() => document.fonts.ready).then(() => 1)")
    pg.wait_for_timeout(120)
    pg.screenshot(path=str(out), omit_background=transparent)
    pg.close()


def svg512(inner, u):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="{LAYER}" height="{LAYER}">{L.defs(u)}{inner}</svg>'


def seigaiha(w, h, R, y0, fill, stroke, op, lw):
    """Seigaiha field with explicit occlusion (fans filled with the background colour)."""
    out = [f'<g opacity="{op}">']
    row, y = 0, y0
    while y < h + R:
        x = -(R if row % 2 else 0)
        while x < w + 2 * R:
            out.append(f'<circle cx="{x}" cy="{y:.1f}" r="{R}" fill="{fill}"/>')
            for k in (1.0, 0.72, 0.44):
                out.append(f'<circle cx="{x}" cy="{y:.1f}" r="{R * k - lw:.1f}" fill="none" stroke="{stroke}" stroke-width="{lw}"/>')
            x += 2 * R
        y += R / 2
        row += 1
    out.append("</g>")
    return "".join(out)


# ----------------------------------------------------------------------------- Plymouth layers
def layers():
    p = L.PLACE
    t = f'translate({L.f(p["cx"])} {L.f(p["cy"])}) rotate({p["rot"]}) scale({p["s"]})'
    out = {
        "tile": svg512('<g clip-path="url(#tsq)"><rect width="512" height="512" fill="url(#tbg)"/>' + L.seigaiha("t") + "</g>"
                       '<rect x=".75" y=".75" width="510.5" height="510.5" rx="113.5" fill="none" stroke="#000" '
                       'stroke-opacity=".07" stroke-width="1.5"/>', "t"),
        "body": svg512(L.ocarina_svg("b", cls=False, holes=False), "b"),
        "seal-prompt": svg512(L.seal_svg("sp", 386, 386, 86, kind="prompt", cls=False), "sp"),
        "seal-kanji": svg512(L.seal_svg("sk", 386, 386, 86, kind="kanji", cls=False), "sk"),
    }
    for i, (x, y, r) in enumerate(L.HOLES):
        hole = (f'<circle cx="{x}" cy="{y}" r="{r}" fill="{L.C["hole"]}"/>'
                f'<path d="M {L.f(x - r * .74)} {L.f(y + r * .42)} A {r} {r} 0 0 0 {L.f(x + r * .74)} {L.f(y + r * .42)}" '
                f'fill="none" stroke="#fff" stroke-opacity=".3" stroke-width="2.6" stroke-linecap="round"/>')
        out[f"hole{i}"] = svg512(f'<g transform="{t}">{hole}</g>', f"h{i}")
    waves = L.waves_svg("w", cls=False).split("<path")[1:]
    for i, wv in enumerate(waves):
        out[f"wave{i}"] = svg512("<path" + wv, "w")
    return out


def message_html(v, key):
    c = VAR[v]
    jp, es = MESSAGES[key]
    return page(f'<div style="height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px">'
                f'<div style="font:500 46px/1 \'Zen Kaku Gothic New\';letter-spacing:.3em;margin-right:-.3em;color:{c["ink"]}">{jp}</div>'
                f'<div style="font:400 22px/1 Geist;letter-spacing:.06em;color:{c["muted"]}">{es}</div></div>', 1200, 150)


def pw_label_html(v):
    c = VAR[v]
    return page(f'<div style="height:100%;display:flex;align-items:center;justify-content:center;gap:14px">'
                f'<span style="font:400 34px/1 \'Yuji Syuku\';color:#e60033">鍵</span>'
                f'<span style="font:500 22px/1 Geist;letter-spacing:.04em;color:{c["muted"]}">Contraseña del disco</span></div>', 800, 60)


def field_html(v):
    c = VAR[v]
    fill = "rgba(255,255,255,.05)" if v == "dark" else "rgba(255,255,255,.85)"
    return page(f'<div style="position:absolute;left:10px;top:6px;width:640px;height:88px;border-radius:44px;background:{fill};'
                f'border:1.5px solid {c["line"]};box-shadow:inset 0 1px 0 rgba(255,255,255,.06)"></div>', 660, 100)


def petal_html():
    return page(f'<svg width="32" height="32" viewBox="-16 -16 32 32"><path d="{L.PETAL}" fill="{L.C["petal"]}" '
                f'transform="rotate(-14) scale(1.12)"/></svg>', 32, 32)


# ----------------------------------------------------------------------------- Limine
def limine_html(v):
    c = VAR[v]
    sei = seigaiha(W, H, 66, 1290, c["bg"], c["pattern"], .07 if v == "dark" else .06, 3)
    if v == "dark":
        logo = (f'<div style="position:absolute;left:{W / 2 - 115}px;top:232px;width:230px;height:230px;'
                f'filter:drop-shadow(0 18px 40px rgba(230,0,51,.28))">{L.icon("li", seal="prompt")}</div>')
        glow = "radial-gradient(ellipse 900px 620px at 50% 19%, rgba(230,0,51,.16), transparent 70%)"
        words_top = 490
    else:
        mark = L.mark("lm").replace("<svg ", '<svg width="340" ', 1)
        logo = f'<div style="position:absolute;left:{W / 2 - 170}px;top:250px;width:340px">{mark}</div>'
        glow = "radial-gradient(ellipse 900px 620px at 50% 19%, rgba(230,0,51,.07), transparent 70%)"
        words_top = 482
    words = (f'<div style="position:absolute;left:0;right:0;top:{words_top}px;text-align:center;font:600 58px/1 Unbounded;'
             f'letter-spacing:-.01em;color:{c["ink"]}">Ocarina<span style="color:#e60033;margin-left:6px">Shell</span></div>'
             f'<div style="position:absolute;left:0;right:0;top:{words_top + 82}px;text-align:center;font:500 22px/1 \'Zen Kaku Gothic New\';'
             f'letter-spacing:.32em;color:{c["muted"]}">オカリナ・シェル</div>')
    card = (f'<div style="position:absolute;left:830px;top:640px;width:1220px;height:520px;border-radius:30px;background:{c["card"]};'
            f'border:1.5px solid {c["line"]};box-shadow:inset 0 1px 0 rgba(255,255,255,.05),0 30px 80px rgba(0,0,0,{.45 if v == "dark" else .08})"></div>')
    kb = (f'display:inline-grid;place-items:center;min-width:38px;height:34px;padding:0 9px;border-radius:9px;border:1.5px solid {c["line"]};'
          f'font:500 18px/1 Geist;color:{c["ink"]};margin:0 8px')
    hints = (f'<div style="position:absolute;left:0;right:0;top:1206px;text-align:center;font:400 21px/34px Geist;color:{c["muted"]}">'
             f'<span style="{kb}">↑</span><span style="{kb};margin-left:0">↓</span> elegir &nbsp;·&nbsp; <span style="{kb}">↵</span> arrancar'
             f' &nbsp;·&nbsp; <span style="{kb}">E</span> editar la línea del kernel</div>')
    note = (f'<div style="position:absolute;left:0;right:0;bottom:92px;text-align:center;font:400 19px/1.5 Geist;color:{c["muted"]};opacity:.85">'
            f'Si algo falla: elige <b style="color:{c["ink"]};font-weight:500">linux-cachyos-lts</b> o un snapshot de '
            f'<b style="color:{c["ink"]};font-weight:500">Snapshots</b> · 守 Mamori guarda uno antes de cada cambio</div>')
    body = (f'<div style="position:absolute;inset:0;background:{glow}"></div>'
            f'<svg style="position:absolute;inset:0" width="{W}" height="{H}">{sei}</svg>'
            f'<div style="position:absolute;inset:0;background:linear-gradient(180deg,{c["bg"]} 0%,{c["bg"]} 62%,transparent 100%)"></div>'
            f'{logo}{words}{card}{hints}{note}')
    return page(body, W, H, bg=c["bg"])


def limine_block(v):
    pal = {"dark": ("0b0a0c;e60033;68be8d;e6b422;6d8fdb;e7609e;00a3af;d7d1c8",
                    "4f4852;ff4d6a;8fd4a9;f5cc52;93acec;f29ac0;4fc6cf;f4efe6", "f4efe6", "ffffff"),
           "light": ("18171c;c4002b;2c7a52;946300;1e50a2;884898;00808a;615b55",
                     "6f6862;e60033;3a9466;b0800f;3a6bc4;a35cb0;008a94;18171c", "18171c", "000000")}[v]
    return f"""# ── OcarinaShell · tema de Limine ({'oscuro' if v == 'dark' else 'claro'}) — generado por tools/boot_assets.py
# Menú centrado dentro de la tarjeta del fondo (2880×1800); sin marca de Limine ni ayuda en inglés (la ayuda va en el fondo);
# terse: sin «Loading kernel…» al arrancar una entrada.
interface_resolution: 2880x1800
interface_branding:
interface_help_hidden: yes
terse: yes
wallpaper: boot():/ocarinashell-limine.png
wallpaper_style: stretched
backdrop: {VAR[v]['bg'].lstrip('#')}
term_font_scale: 2x2
term_margin: 640
term_margin_gradient: 0
term_background: ffffffff
term_foreground: {pal[2]}
term_background_bright: ffffffff
term_foreground_bright: {pal[3]}
term_palette: {pal[0]}
term_palette_bright: {pal[1]}
# ── fin del tema OcarinaShell
"""


TEST_ENTRIES = """
/+CachyOS
//linux-cachyos
    protocol: linux
    path: boot():/vmlinuz-linux-cachyos
    cmdline: quiet splash
    module_path: boot():/initramfs-linux-cachyos.img
//linux-cachyos-lts
    protocol: linux
    path: boot():/vmlinuz-linux-cachyos-lts
    cmdline: quiet splash
    module_path: boot():/initramfs-linux-cachyos-lts.img
/Snapshots
//2026-10-14 03:12 · antes de actualizar (#482)
    protocol: linux
    path: boot():/vmlinuz-linux-cachyos
//2026-10-13 21:05 · fase 13 (#479)
    protocol: linux
    path: boot():/vmlinuz-linux-cachyos
"""


# ----------------------------------------------------------------------------- Plymouth script
PLYMOUTH_INI = """[Plymouth Theme]
Name=OcarinaShell
Description=OcarinaShell — ocarina roja sobre blanco (紅白), arranque y apagado
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/ocarinashell
ScriptFile=/usr/share/plymouth/themes/ocarinashell/ocarinashell.script
"""

SCRIPT = r"""// OcarinaShell — Plymouth script theme. GENERATED by tools/boot_assets.py (edit the generator, not this file).
// Documented script API only (Window, Image, Sprite, Plymouth, Math). Layers share one 760×760 canvas and are drawn at
// 380 px on a 1800 px tall screen, centred at 50 % / 42 % — the greeter and the farewell use the same spot.
variant = "@VARIANT@";                       // dark | light — set by scripts/root/plymouth-tema.sh

W = Window.GetWidth();
H = Window.GetHeight();
k = H / 1800;
CX = W / 2;
CY = H * @CY@;
S = Math.Int(@ICON@ * k);
X0 = Math.Int(CX - S / 2);
Y0 = Math.Int(CY - S / 2);
MSGY = Math.Int(CY + S / 2 + 92 * k);

if (variant == "light") {
    Window.SetBackgroundTopColor(@LR@, @LG@, @LB@);
    Window.SetBackgroundBottomColor(@LR@, @LG@, @LB@);
} else {
    Window.SetBackgroundTopColor(@DR@, @DG@, @DB@);
    Window.SetBackgroundBottomColor(@DR@, @DG@, @DB@);
}

fun layer(name, z) {
    img = Image(name + ".png");
    img = img.Scale(global.S, global.S);
    spr = Sprite(img);
    spr.SetPosition(global.X0, global.Y0, z);
    spr.SetOpacity(0);
    return spr;
}

fun centred(name, y, z) {
    img = Image(name);
    w = Math.Int(img.GetWidth() * global.k);
    h = Math.Int(img.GetHeight() * global.k);
    img = img.Scale(w, h);
    spr = Sprite(img);
    spr.SetPosition(Math.Int(global.CX - w / 2), Math.Int(y - h / 2), z);
    spr.SetOpacity(0);
    return spr;
}

tile = layer("tile", 10);
body = layer("body", 11);
for (i = 0; i < 6; i++)
    hole[i] = layer("hole" + i, 12);
wave[0] = layer("wave0", 12);
wave[1] = layer("wave1", 12);
sealP = layer("seal-prompt", 13);
sealK = layer("seal-kanji", 13);

mode = Plymouth.GetMode();
msgname = "msg-boot";
if (mode == "shutdown") msgname = "msg-shutdown";
if (mode == "reboot") msgname = "msg-reboot";
if (mode == "updates" || mode == "system-upgrade") msgname = "msg-update";
if (mode == "firmware-upgrade") msgname = "msg-firmware";
message = centred(msgname + "-" + variant + ".png", MSGY, 14);

pwLabel = centred("pw-label-" + variant + ".png", MSGY - 20 * k, 15);
pwField = centred("pw-field-" + variant + ".png", MSGY + 100 * k, 15);
petalImg = Image("petal.png");
petalImg = petalImg.Scale(Math.Int(petalImg.GetWidth() * k), Math.Int(petalImg.GetHeight() * k));
asking = 0;
nbullets = 0;
for (i = 0; i < 17; i++) {                          // 17 petals fit in the field; longer passwords still work
    petal[i] = Sprite(petalImg);
    petal[i].SetPosition(Math.Int(CX - 268 * k + i * 31 * k), Math.Int(MSGY + 100 * k - 16 * k), 16);
    petal[i].SetOpacity(0);
}
note = Sprite();
note.SetPosition(Math.Int(CX), Math.Int(H - 90 * k), 17);

// Shutdown and reboot come after the in-session farewell (modules/dengen/Farewell.qml), which already shows the
// icon and message at full strength and plays this same loop: start inside it, 5 frames before a hole sounds, so the
// splash (often on screen for only 1–2 s) moves from its first moment. Boot plays the entrance.
t = 0;
if (mode == "shutdown" || mode == "reboot") t = 280;

fun ramp(t0, len) {
    v = (global.t - t0) / len;
    if (v < 0) v = 0;
    if (v > 1) v = 1;
    return v;
}

fun refresh() {
    global.t = global.t + 1;
    t = global.t;
    global.tile.SetOpacity(ramp(0, 18));
    b = ramp(8, 30);
    global.body.SetOpacity(b);
    global.body.SetY(Math.Int(global.Y0 + (1 - b) * (1 - b) * 16 * global.k));
    for (i = 0; i < 6; i++) {
        o = ramp(22 + i * 3, 10);
        if (t > 75) {                                   // fingering: one hole after another, every 4.2 s
            ph = (t - 75 - i * 22) % 210;
            if (ph >= 0 && ph < 20) o = 0.35 + 0.65 * Math.Abs(ph - 10) / 10;
        }
        global.hole[i].SetOpacity(o);
    }
    for (i = 0; i < 2; i++) {
        o = ramp(40 + i * 7, 15);
        if (t > 75) o = 0.72 + 0.28 * Math.Cos((t - 75 - i * 15) * 2 * Math.Pi / 120);
        global.wave[i].SetOpacity(o * (1 - 0.2 * i));
    }
    s = ramp(56, 10);                                   // hanko: stamp, then ❯_ ⇄ 殻 every 4.5 s
    kj = 0;
    if (t > 120) {
        ph = (t - 120) % 450;
        if (ph >= 213 && ph < 225) kj = (ph - 213) / 12;
        if (ph >= 225 && ph < 438) kj = 1;
        if (ph >= 438) kj = 1 - (ph - 438) / 12;
    }
    global.sealP.SetOpacity(s * (1 - kj));
    global.sealK.SetOpacity(s * kj);
    if (global.asking == 0)
        global.message.SetOpacity(ramp(30, 30));
}
Plymouth.SetRefreshFunction(refresh);

fun display_normal() {
    global.asking = 0;
    global.pwLabel.SetOpacity(0);
    global.pwField.SetOpacity(0);
    for (i = 0; i < 17; i++)
        global.petal[i].SetOpacity(0);
}
Plymouth.SetDisplayNormalFunction(display_normal);

fun display_password(prompt, bullets) {
    global.asking = 1;
    global.message.SetOpacity(0);
    global.pwLabel.SetOpacity(1);
    global.pwField.SetOpacity(1);
    for (i = 0; i < 17; i++) {
        if (i < bullets) global.petal[i].SetOpacity(1);
        else global.petal[i].SetOpacity(0);
    }
}
Plymouth.SetDisplayPasswordFunction(display_password);

fun show_message(text) {
    img = Image.Text(text, @MR@, @MG@, @MB@);
    global.note.SetImage(img);
    global.note.SetX(Math.Int(global.CX - img.GetWidth() / 2));
    global.note.SetOpacity(0.85);
}
Plymouth.SetMessageFunction(show_message);

fun hide_message(text) {
    global.note.SetOpacity(0);
}
Plymouth.SetHideMessageFunction(hide_message);
"""


def script(variant="dark"):
    d, l_ = VAR["dark"]["rgb"], VAR["light"]["rgb"]
    m = (0.66, 0.63, 0.60) if variant == "dark" else (0.38, 0.36, 0.33)
    s = SCRIPT
    for key, val in {"@VARIANT@": variant, "@CY@": str(CY_FRAC), "@ICON@": str(ICON_PX),
                     "@DR@": f"{d[0] / 255:.3f}", "@DG@": f"{d[1] / 255:.3f}", "@DB@": f"{d[2] / 255:.3f}",
                     "@LR@": f"{l_[0] / 255:.3f}", "@LG@": f"{l_[1] / 255:.3f}", "@LB@": f"{l_[2] / 255:.3f}",
                     "@MR@": str(m[0]), "@MG@": str(m[1]), "@MB@": str(m[2])}.items():
        s = s.replace(key, val)
    return s


# ----------------------------------------------------------------------------- previews (what the script draws)
def preview(variant, msg, out, password_bullets=None):
    from PIL import Image
    k = H / 1800
    S = int(ICON_PX * k)
    cx, cy = W / 2, H * CY_FRAC
    x0, y0 = int(cx - S / 2), int(cy - S / 2)
    msgy = int(cy + S / 2 + 92 * k)
    im = Image.new("RGBA", (W, H), VAR[variant]["rgb"] + (255,))
    for name in ["tile", "body"] + [f"hole{i}" for i in range(6)] + ["wave0", "wave1", "seal-prompt"]:
        lay = Image.open(THEME / f"{name}.png").convert("RGBA").resize((S, S), Image.BILINEAR)
        if name == "wave1":
            lay.putalpha(lay.getchannel("A").point(lambda a: int(a * 0.8)))
        im.alpha_composite(lay, (x0, y0))

    def centred(name, y):
        lay = Image.open(THEME / name).convert("RGBA")
        im.alpha_composite(lay, (int(cx - lay.width / 2), int(y - lay.height / 2)))
    if password_bullets is None:
        centred(f"msg-{msg}-{variant}.png", msgy)
    else:
        centred(f"pw-label-{variant}.png", msgy - 20)
        centred(f"pw-field-{variant}.png", msgy + 100)
        petal = Image.open(THEME / "petal.png").convert("RGBA")
        for i in range(min(password_bullets, 17)):
            im.alpha_composite(petal, (int(cx - 268 + i * 31), int(msgy + 100 - 16)))
    im.convert("RGB").save(out, optimize=True)
    print(f"{out.name:30s} {W}×{H}")


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fonts", default=os.environ.get("OCARINA_FONTS", "~/.local/share/fonts/ocarinashell").split(":")[0])
    ap.add_argument("--previews", action="store_true",
                    help="also composite plymouth/preview-*.png with Pillow (the kit ships captures of a real plymouthd)")
    a = ap.parse_args()
    for d in (LIM, PLY, SRC, THEME):
        d.mkdir(parents=True, exist_ok=True)
    fcss = font_css(a.fonts)
    from PIL import Image
    with browser() as b:
        for name, svg in layers().items():
            render(b, f"layer-{name}", page(svg, LAYER, LAYER), LAYER, LAYER, THEME / f"{name}.png", fcss)
        for v in VAR:
            for key in MESSAGES:
                render(b, f"msg-{key}-{v}", message_html(v, key), 1200, 150, THEME / f"msg-{key}-{v}.png", fcss)
            render(b, f"pw-label-{v}", pw_label_html(v), 800, 60, THEME / f"pw-label-{v}.png", fcss)
            render(b, f"pw-field-{v}", field_html(v), 660, 100, THEME / f"pw-field-{v}.png", fcss)
            render(b, f"limine-{v}", limine_html(v), W, H, LIM / f"ocarinashell-limine-{v}.png", fcss, transparent=False)
            (LIM / f"limine-tema-{v}.conf").write_text(limine_block(v))
            (LIM / f"limine-test-{v}.conf").write_text(limine_block(v).replace("interface_resolution:", "timeout: no\ninterface_resolution:", 1)
                                                       + TEST_ENTRIES)
        render(b, "petal", petal_html(), 32, 32, THEME / "petal.png", fcss)
    for p in THEME.glob("*.png"):                      # quantise-free optimisation keeps alpha exact
        Image.open(p).save(p, optimize=True)
    for p in LIM.glob("*.png"):
        if p.name.startswith("ocarinashell-limine"):
            Image.open(p).convert("RGB").save(p, optimize=True)
    (THEME / "ocarinashell.plymouth").write_text(PLYMOUTH_INI)
    (THEME / "ocarinashell.script").write_text(script("dark"))
    if a.previews:
        preview("dark", "boot", PLY / "preview-boot-dark.png")
        preview("dark", "shutdown", PLY / "preview-shutdown-dark.png")
        preview("light", "reboot", PLY / "preview-reboot-light.png")
        preview("dark", "boot", PLY / "preview-password-dark.png", password_bullets=10)
    size = sum(p.stat().st_size for p in THEME.iterdir())
    print(f"plymouth theme: {len(list(THEME.iterdir()))} files, {size // 1024} KB")


if __name__ == "__main__":
    main()
