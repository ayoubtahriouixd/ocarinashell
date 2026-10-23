"""守 Mamori — research and policy (docs/06 capa 6 › Ciclo 3–4, fase 16 §5–6) → plan.json.

Rules, in order (the whole repo batch or nothing; only kernels and linux-firmware may be held alone):
  1. nothing pending                         → nothing (AUR and firmware still go their own way)
  2. a held package of the batch             → hold (Ayoub's holds and Mamori's own, by version)
  3. news asking for manual intervention     → hold until done (Snake reads it; Ayoub answers the notification)
  4. a High/Critical CVE fixed in the batch  → apply now, no maturation
  5. critical packages or major versions     → mature N days since their build (3 with an AI, 7 without); once
                                               mature, Snake reads changelogs and open issues for this hardware: a
                                               regression → hold those packages 3 days (kernels alone, the rest
                                               with their batch)
  6. otherwise                               → apply
Notes with sources go to docs/mantenimiento/AAAA-MM-DD.md (report.py).
"""
import json
import re

from . import ai
from . import aur
from . import common as c

# upstreams whose release notes Snake reads (github-releases via the whitelist of bin/ocarina-snake)
UPSTREAM = {"niri": "niri-wm/niri", "quickshell": "quickshell-mirror/quickshell", "ghostty": "ghostty-org/ghostty",
            "neovim": "neovim/neovim", "pipewire": "PipeWire/pipewire", "wireplumber": "PipeWire/wireplumber"}
# what an issue must mention to matter here (Radeon 860M = RDNA 3.5 gfx1152, Ryzen AI 300 «Krackan Point»)
HARDWARE = "860M OR gfx1152 OR Krackan OR \"RDNA 3.5\" OR \"P14s Gen 6\""
MANUAL_RE = re.compile(r"(?i)manual intervention|intervenci[oó]n manual|requires? (?:manual|user) action|"
                       r"action required|must be (?:done|run) manually")
KERNEL_RE = re.compile(r"^linux(-[a-z0-9]+)*$|^linux-firmware")


def _snake_fetch(*args):
    r = c.run([str(c.BIN / "ocarina-snake"), "fetch", *args, "--json"], timeout=60)
    try:
        return json.loads(r.stdout or "[]")
    except ValueError:
        return []


def installed():
    r = c.run(["pacman", "-Qq"], timeout=30)
    return set(r.stdout.split())


# ── news ────────────────────────────────────────────────────────────────────────────────────
def triage_news(items, batch_names):
    have = installed()
    out = []
    for n in items:
        words = set(re.findall(r"[a-z0-9][a-z0-9+._-]+", n["title"].lower()))
        hits = sorted(w for w in words if w in have)
        e = {"id": n["id"], "title": n["title"], "url": n["url"], "date": n["date"], "source": n["source"],
             "manual": bool(MANUAL_RE.search(n["title"] + " " + n["body"][:3000])),
             "applies": "yes" if hits else "unknown", "packages": hits, "steps": [], "summary": ""}
        r = ai.task("triage-news", f"Paquetes instalados que aparecen en el título: {', '.join(hits) or 'ninguno'}\n"
                                   f"Paquetes del lote pendiente: {', '.join(batch_names[:60]) or 'ninguno'}\n\n"
                                   f"Título: {n['title']}\nEnlace: {n['url']}\n\n{n['body']}")
        if r:
            e["manual"] = bool(r.get("news_asks_manual_steps"))
            e["applies"] = r.get("applies_here", e["applies"])
            e["steps"] = r.get("steps", [])
            e["summary"] = r.get("summary_es", "")
            e["packages"] = r.get("packages", hits) or hits
            e["suspicious"] = bool(r.get("suspicious"))
            e["ai"] = True
        # what counts: a manual step that applies here (or that nobody could rule out)
        e["blocking"] = e["manual"] and e["applies"] != "no"
        out.append(e)
    return out


# ── research for critical packages ──────────────────────────────────────────────────────────
def repo_api_usage():
    """What of each upstream the repo uses (Snake checks the changelog against it)."""
    imports = c.run(["git", "-C", str(c.REPO), "grep", "-hoE", r"^import Quickshell[.A-Za-z]*", "--", "shell"],
                    timeout=20).stdout.split("\n")
    niri = c.run(["git", "-C", str(c.REPO), "grep", "-hoE", r"niri msg( --json)? [a-z-]+", "--", "bin", "shell"],
                 timeout=20).stdout.split("\n")
    return sorted({x.strip() for x in imports + niri if x.strip()})[:80]


def research(pkgs):
    """Snake reads changelogs and open issues of the critical packages → {pkg: {...}}."""
    found = {}
    usage = ", ".join(repo_api_usage())
    for p in pkgs:
        name = p["name"]
        note = {"name": name, "old": p["old"], "new": p["new"], "sources": []}
        repo = UPSTREAM.get(name)
        if repo:
            rel = _snake_fetch("github-releases", repo)
            if rel:
                txt = "\n\n".join(f"## {r['title']} ({r['date']})\n{r['body'][:5000]}" for r in rel[:3])
                note["sources"] += [r["url"] for r in rel[:3]]
                r = ai.task("review-changelog", f"Paquete {name}: {p['old']} → {p['new']}\n"
                                                f"APIs y opciones que usa OcarinaShell: {usage}\n\n{txt}")
                if r:
                    note["changelog"] = {k: r.get(k) for k in ("breaking", "affects_repo", "items", "recommendation",
                                                                "summary_es", "suspicious")}
        issues = []
        base = re.sub(r"^(lib32-|qt6-)", "", name)
        q = f"{base} {_short(p['new'])}"
        for it in _snake_fetch("cachyos-search", q)[:6]:
            issues.append(it)
        if name.startswith(("mesa", "vulkan-radeon", "lib32-mesa")):
            issues += _snake_fetch("gitlab-issues", "gitlab.freedesktop.org/mesa/mesa", "gfx1152")[:6]
        elif repo:
            issues += _snake_fetch("github-issues", repo, "regression")[:6]
        if issues:
            note["sources"] += [i["url"] for i in issues]
            txt = "\n\n".join(f"### {i['title']} [{i.get('state', '')}] {i['date']}\n{i['url']}\n{i['body'][:1500]}"
                              for i in issues)
            r = ai.task("scan-issues", f"Paquete {name} {p['old']} → {p['new']}. Hardware: ThinkPad P14s Gen 6 AMD, "
                                       f"Ryzen AI 7 PRO 350 (Krackan Point), Radeon 860M (RDNA 3.5, gfx1152), "
                                       f"CachyOS, niri, Quickshell.\n\n{txt}")
            if r:
                note["issues"] = {k: r.get(k) for k in ("relevant", "regression_risk", "summary_es", "suspicious")}
        found[name] = note
    return found


def _short(v):
    return v.split(":", 1)[-1].rsplit("-", 1)[0]


def _is_regression(note):
    ch = note.get("changelog") or {}
    iss = note.get("issues") or {}
    if iss.get("regression_risk") == "high" and not iss.get("suspicious"):
        return iss.get("summary_es") or "regresión conocida para este hardware"
    if ch.get("recommendation") == "hold" and not ch.get("suspicious"):
        return ch.get("summary_es") or "el changelog rompe algo que usa OcarinaShell"
    return ""


# ── the decision ────────────────────────────────────────────────────────────────────────────
def decide(inv, interactive=False):
    s = c.settings()
    t = c.now()
    use_ai = ai.available()
    mat = s["maturationDays"] if use_ai else s["maturationDaysNoAi"]
    repo = inv.get("repo", [])
    names = [p["name"] for p in repo]
    fp = " ".join(sorted(f"{p['name']}={p['new']}" for p in repo))
    prev = c.load_json(c.STATE / "plan.json", {}) or {}
    plan = {"at": t, "ai": "snake" if use_ai else "none", "maturationDays": mat, "fingerprint": fp,
            "repo": [{k: p.get(k) for k in ("name", "old", "new", "class", "built", "firstSeen", "severity")}
                     for p in repo],
            "security": [p["name"] for p in repo if "security" in p.get("class", [])],
            "critical": [p["name"] for p in repo if "critical" in p.get("class", [])],
            "major": [p["name"] for p in repo if "major" in p.get("class", [])],
            "kernelHolds": [], "reasons": [], "research": {}, "aur": [], "firmware": inv.get("firmware", [])}

    # news first: they may concern the batch or the system as a whole
    news = triage_news(inv.get("news", []), names) if inv.get("news") else []
    plan["news"] = news
    blocking = [n for n in news if n["blocking"]]

    # holds (Ayoub's: any version; Mamori's: that version only)
    held = []
    for name, h in c.holds().items():
        p = next((x for x in repo if x["name"] == name), None)
        if not p or (h.get("version") and h["version"] != p["new"]):
            continue
        if KERNEL_RE.match(name):
            plan["kernelHolds"].append(name)
        else:
            held.append((name, h))

    if not repo:
        plan["decision"] = "nothing"
    elif held:
        plan["decision"] = "hold"
        plan["until"] = min(h["until"] for _, h in held)
        plan["reasons"] = [f"{n} retenido: {h.get('reason', '')}" for n, h in held]
    elif blocking:
        plan["decision"] = "hold"
        plan["until"] = 0
        plan["reasons"] = [f"noticia con intervención manual: {n['title']}" for n in blocking]
    elif plan["security"]:
        plan["decision"] = "apply"
        plan["reasons"] = ["parche de seguridad (" + ", ".join(plan["security"][:4]) + "): sin maduración"]
    else:
        risky = [p for p in repo if {"critical", "major"} & set(p.get("class", []))]
        if risky and not interactive:
            age_from = {p["name"]: p.get("built") or p.get("firstSeen") or t for p in risky}
            ready_at = max(age_from.values()) + mat * c.DAY
            if ready_at > t:
                plan["decision"] = "mature"
                plan["until"] = ready_at
                plan["reasons"] = [f"madurando {mat} días: " + ", ".join(sorted(age_from)[:5])]
            else:
                plan["decision"] = "apply"
                plan["reasons"] = [f"críticos maduros ({mat} días): " + ", ".join(sorted(age_from)[:5])]
                if use_ai:
                    # the same batch researched already in this state: do not ask Snake twice
                    same = prev.get("fingerprint") == fp and prev.get("research")
                    plan["research"] = prev["research"] if same else research(risky)
                    bad = {n: _is_regression(note) for n, note in plan["research"].items()}
                    bad = {n: why for n, why in bad.items() if why}
                    if bad:
                        for n, why in bad.items():
                            ver = next(p["new"] for p in repo if p["name"] == n)
                            c.set_hold(n, 3, why[:200], "auto", ver)
                        if all(KERNEL_RE.match(n) for n in bad):
                            plan["kernelHolds"] += sorted(bad)
                            plan["reasons"].append("kernel retenido: " + "; ".join(bad.values())[:200])
                        else:
                            plan["decision"] = "hold"
                            plan["until"] = t + 3 * c.DAY
                            plan["reasons"] = [f"{n}: {why}" for n, why in bad.items()]
        else:
            plan["decision"] = "apply"
            plan["reasons"] = ["lote normal" if not interactive else "lo pides tú"]

    # AUR: package by package (leaf applications: no partial-upgrade risk)
    if c.settings()["aur"]:
        prev_aur = {a["name"] + " " + a["new"]: a for a in prev.get("aur", [])}
        for p in inv.get("aur", []):
            h = c.holds().get(p["name"])
            if h and (not h.get("version") or h["version"] == p["new"]):
                plan["aur"].append({"name": p["name"], "old": p["old"], "new": p["new"], "approved": False,
                                    "reason": "retenido: " + h.get("reason", "")})
                continue
            done = prev_aur.get(p["name"] + " " + p["new"])
            plan["aur"].append(done if done and done.get("commit") else aur.review(p))
    return plan
