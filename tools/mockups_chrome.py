#!/usr/bin/env python3
"""Render chosen mockups (tools/mockups.py PAGES) with the system Chrome when Playwright/Pillow are missing:
   python3 tools/mockups_chrome.py 14 15  → assets/mockups/NN-*.png (2880×1800, +1 px of Chrome rounding)."""
import sys, pathlib, subprocess, types
K = pathlib.Path(__file__).resolve().parent.parent
sys.modules["htmlshot"] = types.SimpleNamespace(browser=None)   # Playwright is not installed: Chrome CLI instead
sys.path.insert(0, str(K / "tools"))
import mockups as M
for n in map(int, sys.argv[1:]):
    slug, title, fn, theme = M.PAGES[n]
    html = (f'<!doctype html><html lang="es"><head><meta charset="utf-8"><title>{n:02d} · {title} — OcarinaShell</title>'
            f'<link rel="stylesheet" href="tokens.css"><link rel="stylesheet" href="mock.css"></head>'
            f'<body class="t-{theme}" style="margin:0">{fn()}</body></html>\n')
    src = M.SRC / f"{n:02d}-{slug}.html"
    src.write_text(html)
    png = M.OUT / f"{n:02d}-{slug}.png"
    subprocess.run(["google-chrome-stable", "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1.75", "--window-size=1646,1029", "--virtual-time-budget=3000",
                    "--font-render-hinting=none", "--disable-lcd-text", "--force-color-profile=srgb",
                    f"--screenshot={png}", src.as_uri()], check=True, capture_output=True, timeout=60)
    print(png)
