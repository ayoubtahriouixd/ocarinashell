"""守 Mamori — what is pending (docs/06 capa 6 › Ciclo, 2–3): repos, AUR, news, CVE and firmware, classified.

Nothing here changes the system: checkupdates syncs its own temporary database (in Mamori's cache), paru -Qua asks the
AUR, the news and the security tracker are read over https and are DATA (never instructions).
Classes per package: security (a High/Critical CVE the new version fixes) · critical (docs/06 list) · major (the
first number of the version changes) · aur · rest. Every version gets a first-seen date (inventory.json).
"""
import email.utils
import html
import json
import os
import re
import time
import urllib.request

from . import common as c

CHECKUP_DB = c.CACHE / "mamori/checkup-db"
NEWS_LOOKBACK = 21 * c.DAY      # the first run looks this far back


def _split(line):
    # «name old -> new»
    p = line.split()
    if len(p) >= 4 and p[2] == "->":
        return {"name": p[0], "old": p[1], "new": p[3]}
    return None


def repo_pending():
    """(list, error). Never touches the system's sync database."""
    f = c.fake().get("inventory", {})
    if "repo" in f:
        return f["repo"], ""
    if not c.have("checkupdates"):
        return [], "falta checkupdates (pacman-contrib)"
    CHECKUP_DB.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, CHECKUPDATES_DB=str(CHECKUP_DB), LC_ALL="C")
    r = c.run(["checkupdates"], timeout=300, env=env)
    if r.returncode == 2:
        return [], ""
    if r.returncode != 0:
        return [], f"checkupdates falló ({r.returncode}): {r.stderr.strip()[-200:]}"
    pkgs = [x for x in map(_split, r.stdout.splitlines()) if x]
    # build date and repo of each new version, from the same temporary database
    info = c.run(["pacman", "-Si", "--dbpath", str(CHECKUP_DB), *[p["name"] for p in pkgs]], timeout=60,
                 env=env).stdout
    meta, cur = {}, {}
    for line in info.splitlines() + [""]:
        if not line.strip():
            if cur.get("Name"):
                meta[cur["Name"]] = cur
            cur = {}
            continue
        if " : " in line:
            k, v = line.split(" : ", 1)
            cur[k.strip()] = v.strip()
    for p in pkgs:
        m = meta.get(p["name"], {})
        p["repo"] = m.get("Repository", "")
        try:
            p["built"] = int(time.mktime(time.strptime(m.get("Build Date", ""), "%a %b %d %H:%M:%S %Y")))
        except ValueError:
            p["built"] = 0
    return pkgs, ""


def aur_pending():
    f = c.fake().get("inventory", {})
    if "aur" in f:
        return f["aur"], ""
    if not c.have("paru"):
        return [], ""
    r = c.run(["paru", "-Qua"], timeout=120)
    if r.returncode not in (0, 1):
        return [], f"paru -Qua falló ({r.returncode})"
    return [x for x in map(_split, r.stdout.splitlines()) if x], ""


def _fetch(url, limit=2_000_000):
    req = urllib.request.Request(url, headers={"User-Agent": "OcarinaShell-Mamori/1"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read(limit).decode("utf-8", "replace")


def _rss(url, source):
    out = []
    try:
        x = _fetch(url)
    except Exception as e:      # no network, a timeout, a bad certificate: the news wait for the next cycle
        c.jlog(f"noticias {source}: {e!r}")
        return None
    for it in re.findall(r"(?s)<item>(.*?)</item>", x)[:15]:
        def g(tag):
            m = re.search(rf"(?s)<{tag}>(.*?)</{tag}>", it)
            return html.unescape(m.group(1)).strip() if m else ""
        try:
            ts = int(email.utils.parsedate_to_datetime(g("pubDate")).timestamp())
        except (TypeError, ValueError):
            ts = 0
        body = re.sub(r"<[^>]+>", " ", html.unescape(g("description")))
        body = re.sub(r"\s+", " ", body).strip()
        title = "".join(ch for ch in g("title") if ch.isprintable())[:160]
        link = "".join(ch for ch in g("link") if ch.isprintable())[:300]
        out.append({"source": source, "title": title, "url": link, "date": ts, "body": body[:6000],
                    "id": f"{source}:{link or title}"})
    return out


def news(since):
    f = c.fake().get("inventory", {})
    if "news" in f:
        return f["news"], ""
    items, errs = [], []
    for url, src in (("https://archlinux.org/feeds/news/", "arch"), ("https://cachyos.org/rss.xml", "cachyos")):
        got = _rss(url, src)
        if got is None:
            errs.append(src)
            continue
        items += [n for n in got if n["date"] > since]
    return items, ("sin noticias de " + ", ".join(errs)) if errs else ""


def security(repo):
    """→ ({pkgname: severity} fixed by this batch, open High/Critical count)."""
    f = c.fake().get("inventory", {})
    if "security" in f:
        return f["security"].get("fixed", {}), f["security"].get("open", 0)
    if not c.have("arch-audit"):
        return {}, 0
    r = c.run(["arch-audit", "--json"], timeout=60)
    try:
        avgs = json.loads(r.stdout or "[]")
    except ValueError:
        return {}, 0
    new = {p["name"]: p["new"] for p in repo}
    fixed, open_ = {}, 0
    for a in avgs:
        sev = a.get("severity", "")
        if sev not in ("High", "Critical"):
            continue
        fixes = False
        for name in a.get("packages", []):
            if a.get("fixed") and name in new and \
                    int(c.run(["vercmp", new[name], a["fixed"]], timeout=5).stdout.strip() or -1) >= 0:
                fixed[name] = sev
                fixes = True
        if not fixes:
            open_ += 1
    return fixed, open_


SYSTEM_FW = ("uefi", "system firmware", "embedded controller", "bios", " ec", "dbx")


def firmware():
    f = c.fake().get("inventory", {})
    if "firmware" in f:
        return f["firmware"]
    if not c.have("fwupdmgr"):
        return []
    r = c.run(["fwupdmgr", "get-updates", "--json", "--no-unreported-check", "--no-metadata-check"], timeout=60)
    try:
        devs = json.loads(r.stdout or "{}").get("Devices", [])
    except ValueError:
        return []
    out = []
    for d in devs:
        rel = (d.get("Releases") or [{}])[0]
        if not rel.get("Version"):
            continue
        key = (d.get("Plugin", "") + " " + d.get("Name", "")).lower()
        out.append({"id": d.get("DeviceId", ""), "name": d.get("Name", ""), "old": d.get("Version", ""),
                    "new": rel.get("Version", ""), "summary": (rel.get("Summary") or "")[:200],
                    "system": "internal" in d.get("Flags", []) and any(k in key for k in SYSTEM_FW),
                    "requireAc": "require-ac" in d.get("Flags", [])})
    return out


def _major(v):
    v = v.split(":", 1)[-1]
    m = re.match(r"(\d+)", v)
    return m.group(1) if m else v


def classify(p, sec):
    cls = []
    if p["name"] in sec:
        cls.append("security")
    if re.match(c.CRITICAL_RE, p["name"]):
        cls.append("critical")
    if _major(p["old"]) != _major(p["new"]):
        cls.append("major")
    return cls


def run():
    """→ the inventory dict (also saved). Missing pieces carry an error, never an exception."""
    prev = c.load_json(c.STATE / "inventory.json", {}) or {}
    seen = prev.get("firstSeen", {})
    errors = []
    repo, e = repo_pending()
    if e:
        errors.append(e)
    aur, e = aur_pending()
    if e:
        errors.append(e)
    since = prev.get("newsSince") or (c.now() - NEWS_LOOKBACK)
    items, e = news(since)
    if e:
        errors.append(e)
    handled = set(prev.get("newsHandled", []))
    items = [n for n in items if n["id"] not in handled]
    sec, open_cves = security(repo)
    fw = firmware()
    t = c.now()
    for p in repo:
        p["class"] = classify(p, sec)
        if p["name"] in sec:
            p["severity"] = sec[p["name"]]
        key = f"{p['name']} {p['new']}"
        p["firstSeen"] = seen.get(key, t)
    for p in aur:
        p["class"] = ["aur"]
        p["firstSeen"] = seen.get(f"{p['name']} {p['new']}", t)
    keep = {f"{p['name']} {p['new']}": p["firstSeen"] for p in repo + aur}
    inv = {"at": t, "repo": repo, "aur": aur, "news": items, "openCves": open_cves, "firmware": fw,
           "errors": errors, "firstSeen": keep, "newsSince": prev.get("newsSince", since),
           "newsHandled": sorted(handled)[-200:]}
    if not c.DRY:
        c.save_json(c.STATE / "inventory.json", inv)
    return inv


def mark_news_handled(ids):
    inv = c.load_json(c.STATE / "inventory.json", {}) or {}
    inv["newsHandled"] = sorted(set(inv.get("newsHandled", [])) | set(ids))[-200:]
    if not c.DRY:
        c.save_json(c.STATE / "inventory.json", inv)
