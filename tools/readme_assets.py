#!/usr/bin/env python3
"""Images for the GitHub README, built from the kit's mockups and real boot captures.

    python3 tools/readme_assets.py [--fonts DIR]

→ docs/img/mockups/NN-*.jpg   light previews (1440×900) of assets/mockups/*.png
→ docs/img/arranque/*.jpg     light previews of the real Limine (QEMU) and Plymouth (plymouthd) captures
→ docs/img/recorrido.webp     animated tour (960×600) with a caption on every screen
→ docs/img/social-preview.png 1280×640 image for GitHub → Settings → Social preview
Needs Pillow, plus Chromium via tools/htmlshot.py for the captions and the social image (fonts from --fonts, like
tools/mockups.py; the default is the folder where fase 0 installs them).
"""
import argparse
import os
import pathlib
import sys

from PIL import Image

K = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(K / "tools"))
from htmlshot import browser  # noqa: E402

OUT = K / "docs" / "img"
MOCKS = K / "assets" / "mockups"
BOOT = {"limine-oscuro": "assets/boot/limine/preview-dark.png", "limine-claro": "assets/boot/limine/preview-light.png",
        "plymouth-arranque": "assets/boot/plymouth/preview-boot-dark.png",
        "plymouth-apagado": "assets/boot/plymouth/preview-shutdown-dark.png",
        "plymouth-reinicio": "assets/boot/plymouth/preview-reboot-light.png",
        "plymouth-contrasena": "assets/boot/plymouth/preview-password-dark.png"}
TOUR = [  # (image, kanji, caption) — a full loop: use → shut down → boot → unlock → desktop again
    ("assets/mockups/01-escritorio.png", "帯", "Escritorio · barra Obi, isla Shima y espacios hanko"),
    ("assets/mockups/02-centro-de-control.png", "縁", "Engawa · centro de control con brillo por pantalla"),
    ("assets/mockups/04-lanzador.png", "鳥", "Torii · lanzador"),
    ("assets/mockups/12-pantallas.png", "画", "Ajustes · pantallas, brillo y cuidado del OLED"),
    ("assets/mockups/06-shinobi.png", "忍", "Shinobi · ahorro extremo de batería"),
    ("assets/mockups/08-oni.png", "鬼", "Oni · rendimiento extremo para jugar"),
    ("assets/mockups/09-fune.png", "船", "Fune · apps de Windows como ventanas nativas"),
    ("assets/mockups/11-snake.png", "蛇", "Snake · IA local, gratis y privada"),
    ("assets/mockups/05-energia.png", "電", "Dengen · menú de energía"),
    ("assets/boot/plymouth/preview-shutdown-dark.png", "眠", "Plymouth · apagado (captura real)"),
    ("assets/boot/limine/preview-dark.png", "起", "Arranque · menú de Limine (captura real en QEMU)"),
    ("assets/boot/plymouth/preview-boot-dark.png", "笛", "Plymouth · la ocarina toca al arrancar (captura real)"),
    ("assets/mockups/03-bloqueo.png", "鍵", "Kagi · pantalla de bloqueo"),
]


def jpg(src, dst, size=(1440, 900)):
    im = Image.open(src).convert("RGB").resize(size, Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "JPEG", quality=84, optimize=True, progressive=True, subsampling=0)
    return dst


def font_css(fonts):
    faces = [("Geist", "Geist.ttf"), ("Zen", "ZenKakuGothicNew-Medium.ttf"), ("Mincho", "ShipporiMinchoB1-Bold.ttf"),
             ("Unbounded", "Unbounded.ttf")]
    css = ""
    for fam, f in faces:
        p = pathlib.Path(fonts).expanduser() / f
        if p.exists():
            css += f'@font-face{{font-family:"{fam}";src:url("{p.as_uri()}")}}\n'
    return css


def caption_html(img_uri, kanji, text, css):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{css}
html,body{{margin:0;width:960px;height:600px;overflow:hidden;background:#0b0a0c}}
.bg{{position:absolute;inset:0;background:url("{img_uri}") center/cover}}
.cap{{position:absolute;left:18px;bottom:18px;display:flex;align-items:center;gap:10px;padding:7px 14px 7px 7px;
border-radius:14px;background:rgba(11,10,12,.80);border:1px solid rgba(255,255,255,.09);
box-shadow:0 8px 24px rgba(0,0,0,.45);color:#f4efe6;font:500 15px/1 "Geist","Zen",sans-serif;letter-spacing:.005em}}
.k{{width:30px;height:30px;border-radius:8px;background:#e60033;color:#fff;display:grid;place-items:center;
font:700 17px/1 "Mincho","Zen",serif}}
</style></head><body><div class="bg"></div><div class="cap"><span class="k">{kanji}</span>{text}</div></body></html>"""


SOCIAL = """<!doctype html><html><head><meta charset="utf-8"><style>{css}
html,body{{margin:0;width:1280px;height:640px;overflow:hidden;background:#0b0a0c;color:#f4efe6}}
.glow{{position:absolute;inset:0;background:radial-gradient(60% 80% at 18% 30%,rgba(230,0,51,.20),transparent 70%),
radial-gradient(50% 70% at 95% 100%,rgba(230,0,51,.12),transparent 70%)}}
.logo{{position:absolute;left:30px;top:40px;width:560px}}
.tag{{position:absolute;left:78px;top:478px;width:520px;font:500 20px/1.45 "Geist","Zen",sans-serif;color:#cfc8bf}}
.tag b{{color:#f4efe6;font-weight:600}}
.shot{{position:absolute;left:640px;top:70px;width:780px;border-radius:16px;box-shadow:0 30px 80px rgba(0,0,0,.6),
0 0 0 1px rgba(255,255,255,.08)}}
</style></head><body><div class="glow"></div>
<img class="logo" src="{logo}"><div class="tag"><b>Escritorio japonés</b> para CachyOS · niri · Quickshell,
construido fase a fase por Claude Code.</div><img class="shot" src="{shot}"></body></html>"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fonts", default=os.environ.get("OCARINA_FONTS", "~/.local/share/fonts/ocarinashell").split(":")[0])
    a = ap.parse_args()
    css = font_css(a.fonts)
    if not css:
        print(f"aviso: no hay fuentes en {a.fonts}; los rótulos usarán las del sistema")

    for png in sorted(MOCKS.glob("[0-9][0-9]-*.png")):
        jpg(png, OUT / "mockups" / (png.stem + ".jpg"))
    for name, src in BOOT.items():
        jpg(K / src, OUT / "arranque" / f"{name}.jpg")
    print("previas:", len(list((OUT / "mockups").glob("*.jpg"))), "mockups ·", len(BOOT), "de arranque")

    tmp = OUT / ".tour"
    tmp.mkdir(parents=True, exist_ok=True)
    frames = []
    with browser() as b:
        pg = b.new_page(viewport={"width": 960, "height": 600}, device_scale_factor=1)
        for i, (src, kanji, text) in enumerate(TOUR):
            bg = jpg(K / src, tmp / f"bg{i:02d}.jpg", (1920, 1200))
            html = tmp / f"f{i:02d}.html"
            html.write_text(caption_html(bg.as_uri(), kanji, text, css))
            pg.goto(html.as_uri(), wait_until="load")
            pg.evaluate("document.fonts.ready.then(() => true)")
            pg.wait_for_timeout(120)
            shot = tmp / f"f{i:02d}.png"
            pg.screenshot(path=str(shot))
            frames.append(Image.open(shot).convert("RGB"))
        logo = K / "assets/logo/svg/ocarinashell-hero-animated-dark.svg"
        social_logo = tmp / "logo.png"
        lp = b.new_page(viewport={"width": 1200, "height": 900}, device_scale_factor=1)
        lp.goto(logo.as_uri())
        lp.evaluate("document.getAnimations().forEach(a => { a.pause(); a.currentTime = 5000; })")
        lp.wait_for_timeout(100)
        lp.screenshot(path=str(social_logo), omit_background=True)
        sp = tmp / "social.html"
        sp.write_text(SOCIAL.format(css=css, logo=social_logo.as_uri(),
                                    shot=(OUT / "mockups" / "02-centro-de-control.jpg").as_uri()))
        pg2 = b.new_page(viewport={"width": 1280, "height": 640}, device_scale_factor=1)
        pg2.goto(sp.as_uri(), wait_until="load")
        pg2.evaluate("document.fonts.ready.then(() => true)")
        pg2.wait_for_timeout(150)
        pg2.screenshot(path=str(OUT / "social-preview.png"))

    seq, dur = [], []
    for i, f in enumerate(frames):
        seq.append(f)
        dur.append(2300)
        nxt = frames[(i + 1) % len(frames)]
        for t in (0.25, 0.5, 0.75):
            seq.append(Image.blend(f, nxt, t))
            dur.append(90)
    seq[0].save(OUT / "recorrido.webp", save_all=True, append_images=seq[1:], duration=dur, loop=0, quality=78, method=6)
    for p in tmp.iterdir():
        p.unlink()
    tmp.rmdir()
    kb = (OUT / "recorrido.webp").stat().st_size // 1024
    print(f"recorrido.webp: {len(frames)} pantallas, {kb} KB · social-preview.png 1280×640")


if __name__ == "__main__":
    main()
