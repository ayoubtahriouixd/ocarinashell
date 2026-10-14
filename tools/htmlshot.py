#!/usr/bin/env python3
"""HTML/SVG -> PNG with headless Chromium (Playwright). Shared by logo_png, mockups and boot_assets.

Chromium: the system one is preferred on CachyOS (`sudo pacman -S chromium`, picked up automatically or via
OCARINA_CHROMIUM=/usr/bin/chromium); Playwright's own build (`playwright install chromium`) also works.

    with browser() as b:
        shot(b, html="<svg …>", out="x.png", w=512, h=512, transparent=True)
"""
import contextlib
import os
import shutil

from playwright.sync_api import sync_playwright


def _system_chromium():
    for name in ("chromium", "chromium-browser", "google-chrome-stable", "google-chrome"):
        exe = shutil.which(name)
        if exe:
            return exe
    return None


@contextlib.contextmanager
def browser():
    exe = os.environ.get("OCARINA_CHROMIUM")
    args = ["--font-render-hinting=none", "--disable-lcd-text", "--force-color-profile=srgb"]
    with sync_playwright() as p:
        try:
            b = p.chromium.launch(executable_path=exe, args=args) if exe else p.chromium.launch(args=args)
        except Exception:
            fallback = None if exe else _system_chromium()
            if not fallback:
                raise SystemExit("Chromium not found: `sudo pacman -S chromium` or `playwright install chromium` "
                                 "(or set OCARINA_CHROMIUM)")
            b = p.chromium.launch(executable_path=fallback, args=args)
        try:
            yield b
        finally:
            b.close()


def shot(b, out, html=None, url=None, w=1280, h=800, scale=1.0, transparent=False, clip=None, settle_ms=0):
    """Render `html` (or `url`) in a w×h CSS-pixel viewport at device scale `scale` and save a PNG.
    Waits for web fonts. `clip` = dict(x, y, width, height) in CSS pixels."""
    page = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=scale)
    try:
        if url:
            page.goto(url, wait_until="load")
        else:
            page.set_content(html, wait_until="load")
        page.evaluate("document.fonts.ready.then(() => true)")
        if settle_ms:
            page.wait_for_timeout(settle_ms)
        kw = {"path": str(out), "omit_background": transparent, "animations": "disabled"}
        if clip:
            kw["clip"] = clip
        page.screenshot(**kw)
    finally:
        page.close()


def svg_page(svg, w, h, bg="transparent"):
    """Minimal page that shows one SVG (markup) stretched to exactly w×h CSS pixels."""
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;background:{bg}}}'
            f'svg{{display:block;width:{w}px;height:{h}px}}</style></head><body>{svg}</body></html>')
