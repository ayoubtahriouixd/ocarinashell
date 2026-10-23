"""守 Mamori — one maintenance cycle, step by step and resumable (fase 16 §2).

  conditions → boot → health → inventory → policy → download → install conditions → snapshot → upgrade →
  verify (adapt or roll back) → aur → services → periodic → report

Each finished step is written to status.json (cycle.done). A cycle cut by a shutdown or a suspend resumes where it
stopped: from «snapshot» on, the batch is not recomputed (the plan of that cycle is kept in cycle.data), and an
upgrade that may have been cut is simply run again (pacman -Syu is idempotent; an orphan db.lck is removed first).
A cycle that never got past «policy» is just started again.
"""
import re

from . import adapt
from . import ai
from . import apply
from . import common as c
from . import conditions
from . import health
from . import inventory
from . import periodic
from . import policy
from . import report
from . import rollback
from . import verify

RETRY_MIN = 30


def _step(cyc, name, **data):
    cyc["done"].append(name)
    cyc["step"] = name
    cyc["data"].update(data)
    c.update_status(cycle=cyc)


def schedule_retry(minutes=RETRY_MIN):
    """A transient timer brings the cycle back while conditions are not met (the daily timer is the fallback)."""
    if c.DRY or c.INTERACTIVE or c.sim():
        return
    c.run(["systemd-run", "--user", "--quiet", "--collect", "--unit=ocarina-mamori-retry",
           f"--on-active={minutes}m", "systemctl", "--user", "start", "ocarina-mamori@retry.service"], timeout=10)


def defer(reasons, due=True):
    c.update_status(state="waiting", deferReason=reasons[0] if reasons else "", deferReasons=reasons,
                    due=due, nextTry=c.now() + RETRY_MIN * 60)
    c.say("aplazado: " + "; ".join(reasons))
    c.ping_shell()
    if due:
        schedule_retry()
    return "deferred"


def run(trigger="timer"):
    """→ result string: ok · nothing · deferred · held · rolled-back · failed · paused · busy."""
    st = c.status()
    if st.get("pausedUntil", 0) > c.now():
        c.say(f"en pausa hasta el {c.stamp(st['pausedUntil'])}: no hago nada")
        return "paused"
    lock = c.CycleLock()
    if not lock.acquire():
        c.say("ya hay un ciclo en marcha")
        return "busy"

    apply.clear_reboot_pending_if_booted()
    cyc = st.get("cycle") or {}
    resume = cyc and not cyc.get("finished") and "snapshot" in cyc.get("done", []) and \
        c.now() - cyc.get("started", 0) < 3 * c.DAY
    if not resume:
        cyc = {"id": f"{c.now()}", "started": c.now(), "trigger": trigger, "done": [], "step": "", "data": {}}
    else:
        c.say(f"retomo el ciclo {cyc['id']} tras «{cyc['step']}»")
    c.update_status(state="running", cycle=cyc, lastStart=c.now(), deferReason="", deferReasons=[])
    c.ping_shell()

    try:
        return _run(cyc, resume)
    except Exception as e:
        c.jlog(f"ciclo interrumpido por un error: {e!r}")
        c.history("info", "El ciclo de mantenimiento falló", repr(e)[:300], "fail")
        c.update_status(state="error", lastResult="failed", lastError=repr(e)[:300])
        return "failed"
    finally:
        ai.stop()
        apply.mark_running(False)


def _run(cyc, resume):
    interactive = c.INTERACTIVE
    done = cyc["done"]

    if not resume:
        # ── background conditions (power, network, Oni, call, recording, inhibitors) ──
        cond = conditions.check("background", interactive)
        # health and the boot check need no network: they run even when the rest must wait
        if "boot" not in done:
            rollback.boot_failure()
            _step(cyc, "boot")
        if not cond["ok"] and not interactive:
            only_net = all(r.startswith(("sin conexión", "conexión limitada", "red con límite")) for r in cond["reasons"])
            if only_net and c.on_ac():
                health.run()
            return defer(cond["reasons"])
        if interactive and not cond["ok"]:
            hard = [r for r in cond["reasons"] if r.startswith(("con batería", "batería", "sin conexión",
                                                                    "conexión limitada", "red con límite"))]
            if hard:
                c.say("no puedo ahora: " + "; ".join(hard))
                return "deferred"
        _step(cyc, "conditions")

        problems = health.run()
        _step(cyc, "health", problems=len(problems))
        # a shell restart left from an update made while locked: now, if Ayoub is away and the session unlocked
        if c.status().get("restartPending") and conditions.check("install", interactive)["ok"]:
            verify.pending_restart()

        inv = inventory.run()
        if inv["errors"] and not inv["repo"] and not inv["aur"]:
            c.say("inventario incompleto: " + "; ".join(inv["errors"]))
        _step(cyc, "inventory")

        plan = policy.decide(inv, interactive)
        plan["cycle"] = cyc["id"]
        if not c.DRY:
            c.save_json(c.STATE / "plan.json", plan)
        note = report.notes(plan)
        _step(cyc, "policy", note=note)
        _announce_plan(plan, inv)

        repo_go = plan["decision"] == "apply"
        aur_go = [a for a in plan.get("aur", []) if a.get("approved")]
        fw_go = [d for d in plan.get("firmware", []) if not d.get("system")]
        if not (repo_go or aur_go or fw_go):
            return _finish(cyc, plan, "nothing" if plan["decision"] == "nothing" else "held", inv)

        ok, why = apply.download() if repo_go else (True, "")
        if not ok:
            c.say(f"descarga previa fallida: {why}")
        _step(cyc, "download")

        # ── install conditions: Ayoub away (≥ 10 min idle) or the session locked ──
        cond = conditions.check("install", interactive)
        if not cond["ok"]:
            return defer(cond["reasons"])
        if interactive and not _confirm(plan):
            return _finish(cyc, plan, "nothing", inv)
        snap = apply.snapshot("antes de actualizar")
        if snap is None:
            c.history("update", "No pude crear el snapshot previo", "Sin snapshot no se actualiza nada", "fail")
            return _finish(cyc, plan, "failed", inv)
        _step(cyc, "snapshot", snapshot=snap, plan=plan)
    else:
        plan = cyc["data"]["plan"]
        snap = cyc["data"]["snapshot"]
        inv = c.load_json(c.STATE / "inventory.json", {}) or {}
        cond = conditions.check("install", interactive)
        if not cond["ok"] and "upgrade" not in done:
            return defer(cond["reasons"])

    repo_go = plan["decision"] == "apply"
    names = [p["name"] for p in plan["repo"]]
    apply.mark_running(True)

    if repo_go and "upgrade" not in done:
        cyc["step"] = "upgrade-started"
        c.update_status(cycle=cyc)
        if c.load_json(c.STATE / "health.json", {}).get("orphanDbLock") or resume:
            c.maint("db-unlock", timeout=30)
        rc, out = apply.upgrade(plan.get("kernelHolds", []))
        if rc != 0:
            c.history("update", "La actualización no se completó", out[-300:], "fail")
            ok, fails, _ = verify.after_update(names)
            if not ok:
                _undo(plan, snap, names, "pacman falló y las pruebas están en rojo", fails)
                return _finish(cyc, plan, "rolled-back", inv)
            return _finish(cyc, plan, "failed", inv)
        _step(cyc, "upgrade")

    if repo_go and "verify" not in done:
        ok, fails, active = verify.after_update(names)
        if not ok:
            c.history("update", "Algo falla tras actualizar", "; ".join(fails[:3]), "fail")
            jtxt = health.journal("ocarinashell.service", 150)
            fixed, why = adapt.adapt(fails, jtxt, names)
            if not fixed:
                c.say(f"sin adaptación: {why}")
                _undo(plan, snap, names, "pruebas de humo en rojo; " + why[:120], fails)
                return _finish(cyc, plan, "rolled-back", inv)
        verify.nameraka(names)
        apply.restart_user_services(names)
        crit = [n for n in names if re.match(c.CRITICAL_RE, n)]
        reboot = apply.needs_reboot(names)
        if reboot:
            apply.set_reboot_pending(reboot)
        c.history("update", f"Actualizados {len(names)} paquetes",
                  f"Snapshot #{snap} · pruebas de humo ✓ · " + ("reinicio pendiente (" + ", ".join(reboot[:3]) + ")"
                                                              if reboot else "sin reinicio")
                  + (f" · críticos: {', '.join(crit[:4])}" if crit else ""), "ok", snapshot=snap,
                  packages=len(names), reboot=bool(reboot))
        _step(cyc, "verify")

    if "aur" not in done:
        built, failed = apply.aur_build(plan.get("aur", []))
        if built:
            ok, fails = verify.smoke(False)
            c.history("update", "AUR: " + ", ".join(built), "compilado por root en un entorno aislado · pruebas " +
                      ("✓" if ok else "✗"), "ok" if ok else "fail")
            if not ok:
                rollback.undo_last("el paquete del AUR rompió las pruebas", hold_names=built)
        for name, why in failed:
            c.history("update", f"AUR: {name} no se pudo compilar", why, "fail")
        _step(cyc, "aur")

    if "firmware" not in done:
        staged = apply.firmware_stage([d for d in plan.get("firmware", []) if not d.get("system")])
        if staged:
            c.history("firmware", "Firmware preparado: " + ", ".join(staged), "Se aplica en el próximo reinicio", "ok")
            apply.set_reboot_pending(["firmware"])
        _step(cyc, "firmware")

    return _finish(cyc, plan, "ok", inv)


def _undo(plan, snap, names, why, fails):
    crit = [n for n in names if re.match(c.CRITICAL_RE, n)] or names[:5]
    ok, detail = rollback.undo_last(why, after_snapshot=snap, hold_names=crit)
    title = "Actualización revertida" if ok else "No pude revertir la actualización"
    c.notify(title, f"{why}. " + ("Todo vuelve a estar como antes; el lote queda retenido 7 días."
                                  if ok else detail), "normal" if ok else "critical", tag="rollback")


def _announce_plan(plan, inv):
    if plan["decision"] == "hold" and plan.get("reasons"):
        prev = [e for e in c.read_history(30) if e["kind"] == "hold"]
        title = "Retenido: " + ", ".join((plan.get("critical") or [p["name"] for p in plan["repo"]])[:3]) + \
                " (y su lote)"
        if not prev or prev[-1].get("title") != title:
            until = plan.get("until") or 0
            c.history("hold", title, "; ".join(plan["reasons"])[:300] +
                      (f" · se revisa el {c.stamp(until)[:10]}" if until else ""), "hold")
    told = {e.get("newsId") for e in c.read_history(400)}
    for n in plan.get("news", []):
        if n.get("blocking"):
            if n["id"] in told:
                continue
            steps = "\n".join(f"• {s}" for s in n.get("steps", [])[:5])
            c.notify("Noticia con un paso a mano", f"{n['title']}\n{steps or n['url']}", "normal",
                     actions=[("done", "Hecho"), ("skip", "No me afecta"), ("open", "Abrir")],
                     tag="news-" + c.short_id(n["id"]), payload={"kind": "news", "id": n["id"], "url": n["url"]})
            c.history("hold", "Noticia con intervención manual", n["title"], "attention", url=n["url"], newsId=n["id"])
        else:
            inventory.mark_news_handled([n["id"]])
    for a in plan.get("aur", []):
        if not a.get("approved") and "sospechoso" in a.get("reason", ""):
            c.set_hold(a["name"], 30, a["reason"][:200], "auto", a["new"])
            c.history("review", f"AUR: {a['name']} {a['new']} NO se instala", a["reason"], "attention")
            c.notify("Paquete del AUR sospechoso", f"{a['name']} {a['new']}: {a['reason'][:180]}", "critical",
                     tag="aur")
        elif a.get("approved"):
            c.history("review", f"Snake revisó el PKGBUILD de {a['name']}" if a.get("snake") else
                      f"PKGBUILD de {a['name']} revisado", a.get("reason", ""), "ok")
    for d in plan.get("firmware", []):
        if d.get("system") and c.settings()["firmware"] != "off":
            seen = [e for e in c.read_history(400) if e.get("fwId") == d["id"] and e.get("fwNew") == d["new"]]
            if not seen:
                c.history("firmware", f"Firmware: {d['name']} {d['new']} disponible", "Espera tu aprobación"
                          + (f" ({d['summary']})" if d.get("summary") else ""), "attention", fwId=d["id"],
                          fwNew=d["new"])
                c.notify(f"Firmware: {d['name']} {d['new']}", "Actualizar la BIOS/UEFI necesita tu aprobación "
                         "(con cargador; se instala al reiniciar).", "normal",
                         actions=[("approve", "Aprobar"), ("later", "Más tarde")], tag="fw-" + d["id"][:12],
                         payload={"kind": "firmware", "id": d["id"], "name": d["name"], "new": d["new"]})


def _confirm(plan):
    print(f"\n守 Plan: {plan['decision']} — " + "; ".join(plan.get("reasons", [])))
    print(f"  repos: {len(plan['repo'])} · AUR aprobados: {sum(1 for a in plan.get('aur', []) if a.get('approved'))}")
    for p in plan["repo"][:80]:
        print(f"    {p['name']} {p['old']} → {p['new']}" + (f"  [{', '.join(p['class'])}]" if p.get("class") else ""))
    try:
        ans = input("  ¿Actualizar ahora? [s/N] ")
    except EOFError:
        return False
    return ans.strip().lower() in ("s", "si", "sí", "y", "yes")


def _finish(cyc, plan, result, inv):
    cyc["finished"] = c.now()
    cyc["result"] = result
    periodic_done = []
    if result in ("ok", "nothing", "held") and not c.INTERACTIVE:
        periodic_done = periodic.run()
        report.weekly()
    since = cyc["started"]
    events = report.cycle_events(since)
    note = cyc["data"].get("note", "")
    if events and report.doc_rows(events, note):
        main_ev = next((e for e in events if e["kind"] == "update"), events[0])
        report.commit(f"mamori: {main_ev['title'][:60]}" + (f" (+{len(events) - 1})" if len(events) > 1 else ""))
    upd = [e for e in events if e["kind"] == "update" and e["result"] == "ok" and e.get("reboot")]
    if upd:
        c.notify("Actualizado: reinicia cuando te venga bien", upd[0]["detail"], "low", tag="update")
    reboot_checks(cyc.get("trigger", ""))
    holds_n = len(c.holds())
    summary = {"ok": "Todo en orden", "nothing": "Todo en orden", "held": "Lote retenido",
               "deferred": "Esperando", "rolled-back": "Actualización revertida", "failed": "Algo falló",
               "paused": "En pausa"}.get(result, result)
    attention = [e for e in c.read_history(60) if e["result"] in ("attention", "fail") and
                 c.now() - e["at"] < 7 * c.DAY]
    c.update_status(state="idle", lastRun=c.now(), lastResult=result, summary=summary, due=False,
                    cycle=cyc, nextRun=_next_timer(), holds=holds_n, ai=plan.get("ai", "none"),
                    pending={"repo": 0 if result == "ok" and plan.get("decision") == "apply" else len(plan.get("repo", [])),
                             "aur": len([a for a in plan.get("aur", []) if not (result == "ok" and a.get("approved"))]),
                             "critical": plan.get("critical", []), "security": plan.get("security", []),
                             "decision": plan.get("decision"), "until": plan.get("until", 0)},
                    openCves=inv.get("openCves", 0), maturationDays=plan.get("maturationDays"),
                    attention=len(attention), periodic=[p[0] for p in periodic_done])
    c.say(f"ciclo terminado: {result}")
    c.ping_shell()
    return result


def reboot_checks(trigger):
    """Never forced (docs/06 › Reinicio). A kernel waiting > 7 days → one notification; the nightly reboot only if
    Ayoub turned it on, at night, on AC, with the session locked or idle (the session is saved for 復元 Fukugen)."""
    rp = c.load_json(c.STATE / "reboot-pending")
    if not rp:
        return
    kernel = any(re.match(r"^linux(-[a-z0-9]+)*$", w) for w in rp.get("why", []))
    if kernel and c.now() - rp.get("since", c.now()) > 7 * c.DAY and not rp.get("nagged"):
        c.notify("Kernel nuevo esperando desde hace una semana", "Incluye arreglos (también de seguridad) que solo "
                 "entran al reiniciar.", "normal", actions=[("now", "Reiniciar ahora"), ("tonight", "Esta noche"),
                                                           ("later", "Más tarde")], tag="reboot",
                 payload={"kind": "reboot"})
        if not c.DRY:
            rp["nagged"] = c.now()
            c.save_json(c.STATE / "reboot-pending", rp)
    import time
    hour = time.localtime().tm_hour
    tonight = rp.get("tonight") and 2 <= hour < 6
    if (c.settings()["nightlyReboot"] or tonight) and trigger == "timer" and 2 <= hour < 6 and c.on_ac():
        sh = conditions.shell_state() or {}
        if sh.get("locked") or sh.get("idle10"):
            reboot_now("reinicio nocturno")


def reboot_now(why):
    c.history("info", "Reinicio para terminar la actualización", why, "info")
    if c.DRY:
        c.say("[dry-run] ocarina session save && systemctl reboot")
        return
    c.run([str(c.BIN / "ocarina"), "session", "save"], timeout=30)
    c.run(["systemctl", "reboot"], timeout=30)


def _next_timer():
    return c.next_timer()
