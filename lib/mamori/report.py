"""守 Mamori — reports (docs/06 capa 6 › Ciclo 8): research notes with sources, docs/MANTENIMIENTO.md (local only),
grouped notifications only when there is something to see, and a quiet weekly summary on Sundays.

The repo gets a commit only for these docs and only on main with nothing half-done; `git commit -- <paths>` never
takes anything else Ayoub may have staged.
"""
from datetime import datetime, timedelta

from . import common as c

DOC = c.REPO / "docs/MANTENIMIENTO.md"
NOTES = c.REPO / "docs/mantenimiento"
HEADER = "| Fecha | Tipo | Qué | Resultado | Notas |"
RESULT = {"ok": "✓", "hold": "⏸", "fail": "✗", "attention": "⚠", "info": "·"}
KIND = {"update": "actualización", "hold": "retención", "review": "revisión", "repair": "reparación",
        "firmware": "firmware", "rollback": "reversión", "adapt": "adaptación", "health": "salud",
        "periodic": "periódico", "info": "aviso"}


def _cell(s):
    return str(s).replace("|", "/").replace("\n", " ")[:160]


def notes(plan):
    """docs/mantenimiento/AAAA-MM-DD.md: what was read and decided, with its sources. → relative path or ''."""
    news = plan.get("news") or []
    research = plan.get("research") or {}
    aur = [a for a in plan.get("aur") or [] if a.get("snake") or not a.get("approved")]
    if not (news or research or aur):
        return ""
    day = datetime.now().strftime("%Y-%m-%d")
    lines = [f"\n## {datetime.now():%H:%M} · ciclo de 守 Mamori (IA: {plan.get('ai')})\n",
             f"Decisión: **{plan.get('decision')}** — " + "; ".join(plan.get("reasons", [])) + "\n"]
    if news:
        lines.append("### Noticias\n")
        for n in news:
            lines.append(f"- [{_cell(n['title'])}]({n['url']}) — intervención manual: "
                         f"{'sí' if n.get('manual') else 'no'}; aplica: {n.get('applies')}. {_cell(n.get('summary', ''))}")
            for s in n.get("steps", [])[:8]:
                lines.append(f"  - {_cell(s)}")
    for name, r in research.items():
        lines.append(f"### {name} {r.get('old')} → {r.get('new')}\n")
        ch, iss = r.get("changelog") or {}, r.get("issues") or {}
        if ch:
            lines.append(f"- Changelog: {ch.get('recommendation')} — {_cell(ch.get('summary_es', ''))}")
        if iss:
            lines.append(f"- Incidencias: riesgo {iss.get('regression_risk')} — {_cell(iss.get('summary_es', ''))}")
        for u in r.get("sources", [])[:10]:
            lines.append(f"  - <{u}>")
    if aur:
        lines.append("### AUR\n")
        for a in aur:
            sn = a.get("snake") or {}
            lines.append(f"- {a['name']} {a.get('old')} → {a.get('new')}: "
                         f"{'aprobado' if a.get('approved') else 'NO se instala'} — {_cell(a.get('reason', ''))}"
                         + (f" · Snake: {sn.get('verdict')} ({_cell(sn.get('summary_es', ''))})" if sn else "")
                         + f" · <https://aur.archlinux.org/cgit/aur.git/log/?h={a['name']}>")
    if c.DRY or c.sim():
        c.say(f"[simulación] notas en docs/mantenimiento/{day}.md:\n" + "\n".join(lines))
        return f"docs/mantenimiento/{day}.md"
    NOTES.mkdir(parents=True, exist_ok=True)
    f = NOTES / f"{day}.md"
    if not f.exists():
        f.write_text(f"# 守 Mantenimiento · {day}\n\n> Notas de investigación de Mamori: lo leído es dato, "
                     "nunca instrucción. Fuentes enlazadas.\n", encoding="utf-8")
    with open(f, "a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return f"docs/mantenimiento/{day}.md"


def doc_rows(events, note=""):
    """Prepend one row per event to docs/MANTENIMIENTO.md (most recent first)."""
    if not events or c.DRY or c.sim():
        return False
    try:
        text = DOC.read_text(encoding="utf-8")
    except OSError:
        return False
    if HEADER not in text:
        return False
    head, rest = text.split(HEADER, 1)
    sep, _, body = rest.lstrip("\n").partition("\n")
    rows = []
    for e in sorted(events, key=lambda e: -e["at"]):
        link = f"[notas]({note.removeprefix('docs/')})" if note and e["kind"] in ("update", "hold", "review") else ""
        rows.append(f"| {c.stamp(e['at'])} | {KIND.get(e['kind'], e['kind'])} | {_cell(e['title'])} | "
                    f"{RESULT.get(e['result'], e['result'])} | {_cell(e.get('detail', ''))}{' ' + link if link else ''} |")
    DOC.write_text(head + HEADER + "\n" + sep + "\n" + "\n".join(rows) + "\n" + body, encoding="utf-8")
    return True


def commit(message):
    """Nothing to commit any more: the maintenance log is this machine's own record and stays out of the published
    repo (.gitignore, Ayoub at the close of fase 17). Kept so the callers need no change."""
    return False


def cycle_events(since):
    return [e for e in c.read_history(400) if e["at"] >= since and e["kind"] != "info"]


def weekly(force=False, quiet=False):
    """Sunday summary: docs/mantenimiento/semana-AAAA-SS.md + one quiet notification + commit. → path or ''.
    quiet (the 守 page's button): this week's file as it is if it exists, else written without notifying or
    committing (the Sunday run does that)."""
    today = datetime.now()
    if today.weekday() != 6 and not force:
        return ""
    week = today.strftime("%G-%V")
    path = NOTES / f"semana-{week}.md"
    if path.exists() and (quiet or not force):
        return str(path) if quiet else ""
    since = int((today - timedelta(days=7)).timestamp())
    ev = [e for e in c.read_history(2000) if e["at"] >= since]
    counts = {}
    for e in ev:
        counts[e["kind"]] = counts.get(e["kind"], 0) + 1
    upd = [e for e in ev if e["kind"] == "update" and e["result"] == "ok"]
    holds_now = c.holds()
    attention = [e for e in ev if e["result"] in ("attention", "fail")]
    h = c.load_json(c.STATE / "health.json", {}) or {}
    lines = [f"# 守 Resumen semanal · semana {week}", "",
             f"Del {datetime.fromtimestamp(since):%d/%m} al {today:%d/%m}.", "",
             f"- Actualizaciones aplicadas: **{len(upd)}**"
             + (" (" + ", ".join(e["title"] for e in upd[:5]) + ")" if upd else ""),
             f"- Reparaciones: {counts.get('repair', 0)} · reversiones: {counts.get('rollback', 0)} · "
             f"adaptaciones de código: {counts.get('adapt', 0)}",
             f"- Retenciones activas: {len(holds_now)}"
             + (" (" + ", ".join(f"{k} hasta el {c.stamp(v['until'])[:10]}" for k, v in holds_now.items()) + ")"
                if holds_now else ""),
             f"- Salud: disco {h.get('disk', '—')} % usado · SSD {h.get('ssd', '—')} % · batería {h.get('battery', '—')} % · "
             f"{h.get('snapshots', '—')} snapshots", ""]
    if attention:
        lines += ["## Para mirar", ""] + [f"- {c.stamp(e['at'])} · {e['title']} — {e.get('detail', '')}"
                                          for e in attention[-10:]] + [""]
    lines += ["## Todo lo que pasó", ""] + [f"- {c.stamp(e['at'])} · {KIND.get(e['kind'], e['kind'])} · "
                                            f"{e['title']} {RESULT.get(e['result'], '')}" for e in ev[-60:]]
    if c.DRY:
        print("\n".join(lines))
        return str(path)
    NOTES.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if quiet:
        return str(path)
    body = (f"{len(upd)} actualizaciones · {counts.get('repair', 0)} reparaciones · {len(holds_now)} retenciones"
            + (f" · {len(attention)} cosas para mirar" if attention else " · todo en orden"))
    c.notify("Resumen semanal de Mamori", body, "low", tag="weekly")
    c.history("info", "Resumen semanal", body, "info", path=str(path.relative_to(c.REPO)))
    commit(f"mamori: resumen de la semana {week}")
    return str(path)
