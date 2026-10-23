"""守 Mamori — AUR updates (docs/06 capa 2 and fase 16 §5).

For each AUR update: the package's AUR git repo is cloned/fetched into Mamori's cache; the BASE is the newest commit
whose .SRCINFO matches the installed version, the TARGET is the AUR's HEAD (its .SRCINFO must match the version paru
announced). Approved when the diff is trivial (deterministic: only pkgver, pkgrel, checksums and the version inside
URLs change, only PKGBUILD/.SRCINFO touched) or, with an AI, when Snake's `review-pkgbuild` says benign and not
suspicious. The approval is the TARGET commit hash: root (`ocarina-maint aur-build <pkg> <commit>`) fetches that exact
commit from the AUR itself, builds it as a throw-away unprivileged user and installs it — nothing built by Ayoub's
user ever runs as root.
"""
import re

from . import ai
from . import common as c

AUR = "https://aur.archlinux.org"
WORK = c.CACHE / "mamori/aur"
SUMS_RE = re.compile(r"(?ms)^\s*(?:sha\d+sums|b2sums|md5sums|cksums)(?:_[A-Za-z0-9_]+)?=\((.*?)\)")
SUMS1_RE = re.compile(r"(?m)^\s*(?:sha\d+sums|b2sums|md5sums|cksums)(?:_[A-Za-z0-9_]+)?=['\"]?[0-9a-fA-F]*['\"]?\s*$")


def _git(repo, *args, timeout=120):
    return c.run(["git", "-C", str(repo), *args], timeout=timeout)


def _srcinfo_version(text):
    v = {}
    for line in text.splitlines():
        m = re.match(r"\s*(epoch|pkgver|pkgrel)\s*=\s*(\S+)", line)
        if m and m.group(1) not in v:
            v[m.group(1)] = m.group(2)
    if "pkgver" not in v:
        return ""
    return (v["epoch"] + ":" if v.get("epoch") else "") + v["pkgver"] + "-" + v.get("pkgrel", "1")


def fetch(pkg):
    """Clone or update the AUR repo of pkg (user cache). → path or None."""
    d = WORK / pkg
    if not re.fullmatch(r"[a-z0-9@_+][a-z0-9@._+-]{0,99}", pkg):
        return None
    if (d / ".git").is_dir():
        r = _git(d, "fetch", "--quiet", "origin")
    else:
        WORK.mkdir(parents=True, exist_ok=True)
        r = c.run(["git", "clone", "--quiet", f"{AUR}/{pkg}.git", str(d)], timeout=180)
    return d if r.returncode == 0 else None


def find_commits(d, old, new):
    """(base, target) commit hashes, or None where not found."""
    head = _git(d, "rev-parse", "origin/HEAD").stdout.strip() or _git(d, "rev-parse", "origin/master").stdout.strip()
    target = head if head and _srcinfo_version(_git(d, "show", f"{head}:.SRCINFO").stdout) == new else None
    base = None
    for h in _git(d, "log", "--format=%H", "origin/HEAD" if head else "origin/master", "--", ".SRCINFO").stdout.split():
        if _srcinfo_version(_git(d, "show", f"{h}:.SRCINFO").stdout) == old:
            base = h
            break
    return base, target


def _version_parts(v):
    v = v.split(":", 1)[-1]
    return v.rsplit("-", 1)[0]


def normalize(text, pkgver):
    t = SUMS_RE.sub("@SUMS@", text)
    t = SUMS1_RE.sub("@SUMS@", t)
    t = re.sub(r"(?m)^\s*pkgrel=.*$", "@PKGREL@", t)
    if pkgver:
        t = t.replace(pkgver, "@V@")
        # the same version with other separators (8059_84, 8059-84) inside URLs
        for sep in ("_", "-"):
            t = t.replace(pkgver.replace(".", sep), "@V@")
    return t


def trivial(d, base, target, old, new):
    """Deterministic: (bool, reason)."""
    files = _git(d, "diff", "--name-only", base, target).stdout.split()
    extra = [f for f in files if f not in ("PKGBUILD", ".SRCINFO")]
    if extra:
        return False, "cambia otros ficheros: " + ", ".join(extra[:5])
    a = _git(d, "show", f"{base}:PKGBUILD").stdout
    b = _git(d, "show", f"{target}:PKGBUILD").stdout
    if normalize(a, _version_parts(old)) == normalize(b, _version_parts(new)):
        return True, "solo cambian la versión y las sumas"
    return False, "el PKGBUILD cambia más que la versión y las sumas"


def review(p):
    """One AUR update → decision dict {name, old, new, commit, approved, trivial, reason, snake?}."""
    out = {"name": p["name"], "old": p["old"], "new": p["new"], "approved": False, "commit": "", "trivial": False}
    f = c.fake().get("aur_review", {}).get(p["name"])
    if f:        # simulations: {"diff": "...", "trivial": false}
        out.update(commit="0" * 40, trivial=f.get("trivial", False), reason=f.get("reason", "simulado"))
        diff = f.get("diff", "")
    else:
        d = fetch(p["name"])
        if d is None:
            out["reason"] = "no pude descargar su repositorio del AUR"
            return out
        base, target = find_commits(d, p["old"], p["new"])
        if not target:
            out["reason"] = "el AUR no tiene aún la versión anunciada"
            return out
        out["commit"] = target
        if not base:
            out["reason"] = "no encuentro el PKGBUILD de la versión instalada para comparar"
            diff = _git(d, "show", f"{target}:PKGBUILD").stdout
        else:
            out["trivial"], out["reason"] = trivial(d, base, target, p["old"], p["new"])
            diff = _git(d, "diff", base, target, "--", ".", ":(exclude).SRCINFO").stdout
    if out["trivial"]:
        out["approved"] = True
    if ai.available():
        r = ai.task("review-pkgbuild", f"Paquete del AUR: {p['name']} {p['old']} → {p['new']}\n"
                                       f"Comprobación determinista: {'trivial' if out['trivial'] else 'NO trivial'}"
                                       f" ({out.get('reason', '')})\n\nDiff del PKGBUILD y ficheros:\n{diff}")
        if r:
            out["snake"] = {k: r.get(k) for k in ("verdict", "trivial", "reasons", "summary_es", "suspicious",
                                                  "suspicious_reason")}
            if r.get("verdict") == "suspicious" or r.get("suspicious"):
                # Snake's doubt always wins over the deterministic check
                out["approved"] = False
                out["reason"] = "Snake lo marca como sospechoso: " + (r.get("suspicious_reason") or
                                                                      "; ".join(r.get("reasons", []))[:200])
            elif r.get("verdict") == "benign":
                out["approved"] = True
                out["reason"] = out.get("reason", "") + " · Snake: sin nada raro"
    elif not out["trivial"]:
        out["reason"] = out.get("reason", "") + " · sin IA: espera a una versión con diff trivial o a Snake"
    return out
