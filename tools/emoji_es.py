#!/usr/bin/env python3
"""Write assets/data/emoji-es.json: Spanish names and keywords of every emoji, for Torii's `:` search.

Source: Unicode CLDR annotations (cldr-json, `es` locale, base + derived), Unicode License v3 — the notice is kept
in the output's `license` field. Skin-tone variants are left out (the shell shows the base emoji only).
Run once per CLDR release; the shell never downloads anything for this.

usage: python3 tools/emoji_es.py [cldr-version=48.0.0] [out=assets/data/emoji-es.json]
"""
import json
import pathlib
import sys
import urllib.request

K = pathlib.Path(__file__).resolve().parent.parent
VERSION = sys.argv[1] if len(sys.argv) > 1 else "48.0.0"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else K / "assets/data/emoji-es.json"
BASE = f"https://raw.githubusercontent.com/unicode-org/cldr-json/{VERSION}/cldr-json"
SOURCES = [
    f"{BASE}/cldr-annotations-full/annotations/es/annotations.json",
    f"{BASE}/cldr-annotations-derived-full/annotationsDerived/es/annotations.json",
]
SKIN_TONES = {chr(c) for c in range(0x1F3FB, 0x1F400)}
# Japanese words people will type for the emoji of this desktop's world
EXTRA = {
    "🌸": "sakura hanami", "🍙": "onigiri", "🍡": "dango", "⛩": "torii jinja", "🗻": "fuji fujisan",
    "🎏": "koinobori", "🎐": "furin", "🍵": "matcha ocha", "🍶": "sake", "🍱": "bento", "🦊": "kitsune",
    "🏯": "shiro", "👺": "tengu", "👹": "oni", "🌊": "nami", "🎋": "tanabata", "🎍": "kadomatsu",
    "🍜": "ramen", "🍘": "senbei", "🎎": "hina", "🗾": "nihon japon", "🍥": "naruto kamaboko", "🥷": "shinobi",
}


def fetch(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=30) as r:
        data = json.load(r)
    root = data.get("annotations") or data.get("annotationsDerived")
    return root["annotations"]


def main() -> int:
    names: dict[str, str] = {}
    for url in SOURCES:
        for emoji, a in fetch(url).items():
            if any(c in SKIN_TONES for c in emoji):
                continue
            tts = (a.get("tts") or [""])[0]
            words = [w for w in a.get("default", []) if w.lower() != tts.lower()]
            words += EXTRA.get(emoji.replace("\ufe0f", ""), "").split()
            if tts:
                # "name|keyword keyword…": the name is shown, the whole line is searched
                names[emoji.replace("\ufe0f", "")] = tts + ("|" + " ".join(words) if words else "")
    out = {
        "comment": f"Nombres de emoji en español (Unicode CLDR {VERSION}). Generado por tools/emoji_es.py.",
        "license": "Unicode License v3 · © 1991-2025 Unicode, Inc. · https://www.unicode.org/license.txt",
        "names": dict(sorted(names.items())),
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{OUT}: {len(names)} emoji, {OUT.stat().st_size // 1024} KiB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
