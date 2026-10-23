#!/usr/bin/env python3
"""Prepare a GitHub release of OcarinaShell.

    python3 tools/release.py v1.0.0 [--repo usuario/ocarinashell]

--repo writes the repository into every file that still has the __GITHUB_REPO__ placeholder (README.md, install.sh,
CHANGELOG.md…). Then it builds, in dist/:
  ocarinashell-<version>.zip   root folder ocarinashell/; the repo's files (tracked + new, minus .gitignore),
                                   reproducible: sorted entries and the date of the version
  SHA256SUMS                       the zip's checksum
  RELEASE-NOTES.md                 that version's CHANGELOG section + how to install
Standard library only.
"""
import argparse
import datetime
import hashlib
import os
import pathlib
import re
import subprocess
import sys
import zipfile

K = pathlib.Path(__file__).resolve().parent.parent
PLACEHOLDER = "__GITHUB" + "_REPO__"   # split so this file never matches itself
SKIP_DIRS = {".git", "dist", "__pycache__"}


def files():
    if (K / ".git").exists():
        out = subprocess.run(["git", "-C", str(K), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                             check=True, capture_output=True).stdout.decode()
        names = sorted({n for n in out.split("\0") if n and (K / n).is_file()})
    else:
        names = sorted(str(p.relative_to(K)) for p in K.rglob("*")
                       if p.is_file() and not SKIP_DIRS & set(p.relative_to(K).parts) and p.suffix != ".pyc")
    return names


def current_repo():
    # GitHub Actions says where it runs; by hand, the public repository
    return os.environ.get("GITHUB_REPOSITORY") or "ayoubtahriouixd/ocarinashell"


def set_repo(repo):
    """Write usuario/repo wherever the placeholder (or a previously configured repo) appears."""
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]{1,100}", repo):
        sys.exit(f"--repo inválido: {repo} (formato usuario/repo)")
    old = {PLACEHOLDER} | ({current_repo()} - {None, repo})
    changed = []
    for name in files():
        p = K / name
        if name == "tools/release.py" or p.suffix.lower() in {".png", ".jpg", ".webp", ".wav", ".ttf", ".qsb", ".zip"}:
            continue
        try:
            s = p.read_text()
        except UnicodeDecodeError:
            continue
        t = s
        for o in old:
            t = t.replace(o, repo)
        if t != s:
            p.write_text(t)
            changed.append(name)
    print("repo escrito en:", ", ".join(changed) or "(ya estaba)")


def notes(version, repo):
    log = (K / "CHANGELOG.md").read_text()
    m = re.search(rf"^## \[{re.escape(version.lstrip('v'))}\][^\n]*\n(.*?)(?=^## \[|^\[[^\]]+\]: |\Z)", log, re.S | re.M)
    if not m:
        sys.exit(f"CHANGELOG.md no tiene la sección [{version.lstrip('v')}]")
    return (m.group(1).strip() + f"""

### Instalar

```bash
git clone https://github.com/{repo} ~/ocarinashell
cd ~/ocarinashell && ./install.sh
```

`./install.sh --demo` enseña todo el recorrido sin cambiar nada. Sin git: descarga `ocarinashell-{version}.zip` y
`SHA256SUMS`, comprueba con `sha256sum -c SHA256SUMS --ignore-missing`, descomprime en `~/ocarinashell` y ejecuta
`./install.sh`.

### Actualizar

```bash
cd ~/ocarinashell && git pull && ./install.sh
```

Tus ajustes viven fuera del repo (`~/.config/ocarinashell`, `~/.local/state/ocarinashell`): actualizar no los toca.
""")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("version", help="vX.Y.Z")
    ap.add_argument("--repo", help="usuario/repo de GitHub")
    a = ap.parse_args()
    if not re.fullmatch(r"v\d+\.\d+\.\d+", a.version):
        sys.exit("versión con formato vX.Y.Z")
    if a.repo:
        set_repo(a.repo)
    left = [n for n in files() if (K / n).suffix in {".md", ".sh", ".py", ".yml"} and n != "tools/release.py"
            and PLACEHOLDER in (K / n).read_text()]
    if left:
        sys.exit("Falta el repositorio (--repo usuario/repo) en: " + ", ".join(left))
    repo = a.repo or current_repo()

    m = re.search(rf"^## \[{re.escape(a.version.lstrip('v'))}\] · (\d{{4}}-\d{{2}}-\d{{2}})", (K / "CHANGELOG.md").read_text(), re.M)
    day = datetime.date.fromisoformat(m.group(1)) if m else datetime.date.today()
    stamp = (day.year, day.month, day.day, 0, 0, 0)

    dist = K / "dist"
    dist.mkdir(exist_ok=True)
    zpath = dist / f"ocarinashell-{a.version}.zip"
    names = files()
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for n in names:
            p = K / n
            zi = zipfile.ZipInfo(f"ocarinashell/{n}", date_time=stamp)
            zi.external_attr = (0o755 if os.access(p, os.X_OK) else 0o644) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(zi, p.read_bytes(), compresslevel=9)
    sums = []
    for p in (zpath,):
        sums.append(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}")
    (dist / "SHA256SUMS").write_text("\n".join(sums) + "\n")
    (dist / "RELEASE-NOTES.md").write_text(notes(a.version, repo))
    mb = zpath.stat().st_size / 1e6
    print(f"{zpath.relative_to(K)}: {len(names)} ficheros, {mb:.1f} MB")
    print("dist/SHA256SUMS:\n  " + "\n  ".join(sums))
    print("dist/RELEASE-NOTES.md")


if __name__ == "__main__":
    main()
