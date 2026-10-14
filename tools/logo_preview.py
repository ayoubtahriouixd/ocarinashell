#!/usr/bin/env python3
"""Build assets/logo/preview.html: every animated variant on one page (open it in a browser).

usage: python3 tools/logo_preview.py [svgdir] [out.html]      (run logo_gen.py first)
"""
import pathlib
import sys

K = pathlib.Path(__file__).resolve().parent.parent

CARDS = [  # file, css classes, caption
    ("ocarinashell-icon-animated.svg", "icon", "Icono animado"),
    ("ocarinashell-icon-kanji.svg", "icon", "Variante sello 殻"),
    ("ocarinashell-icon-flat.svg", "icon", "Plano (tamaños pequeños, barra)"),
    ("ocarinashell-wordmark-animated-light.svg", "wide", "Wordmark · fondo claro"),
    ("ocarinashell-wordmark-animated-dark.svg", "wide dark", "Wordmark · fondo oscuro"),
    ("ocarinashell-hero-animated-dark.svg", "wide dark", "Hero · pantalla de bloqueo / Acerca de / greeter"),
]

HEAD = """<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>OcarinaShell · Logo</title><style>
:root{--bg:#f6f3ee;--ink:#18171c;--muted:#8a847d;--red:#e60033}
*{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,sans-serif}
header{padding:28px 16px 8px;max-width:1100px;margin:auto} h1{margin:0;font-size:20px} p{color:var(--muted);margin:4px 0 0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px;padding:16px 16px 40px;max-width:1100px;margin:auto}
.card{background:#fff;border-radius:18px;padding:18px;box-shadow:0 8px 30px rgba(0,0,0,.05);display:flex;flex-direction:column;gap:10px;align-items:center;justify-content:center}
.card.dark{background:radial-gradient(circle at 50% 30%,#24161c,#0a090c 75%);color:#ddd}
.wide{grid-column:1/-1} .card svg{width:100%;height:auto;display:block} .icon svg{max-width:260px}
small{color:var(--muted)} button{border:0;background:var(--red);color:#fff;border-radius:99px;padding:8px 16px;font-weight:600;cursor:pointer}
</style></head><body>
<header><h1>OcarinaShell — 紅白 · rojo sobre blanco</h1>
<p>Intro: cuerpo, agujeros, ondas y sello hanko. Después, bucles suaves (flotación, «digitación» en los agujeros, brillo lacado, ondas). El sello alterna entre ❯_ (shell) y 殻 (kara: «cáscara/concha», el shell en japonés).</p>
<p style="margin-top:10px"><button onclick="document.querySelectorAll('.card svg').forEach(s=>s.replaceWith(s.cloneNode(true)))">Repetir animación</button></p></header>
<div class="grid">"""


def main(svgdir, out):
    svgdir = pathlib.Path(svgdir)
    cards = [f'<div class="card {cls}">{(svgdir / name).read_text()}<small>{cap}</small></div>' for name, cls, cap in CARDS]
    pathlib.Path(out).write_text(HEAD + "\n".join(cards) + "</div></body></html>\n")
    print("wrote", out)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0] if a else K / "assets/logo/svg", a[1] if len(a) > 1 else K / "assets/logo/preview.html")
