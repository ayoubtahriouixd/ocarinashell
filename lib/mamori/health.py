"""守 Mamori — health and self-repair (docs/06 capa 6 › Autorreparación).

Each playbook row is check → action → verification. A repair that fails is not repeated more than twice a day;
after that the problem goes to Snake (`diagnose`) once and into the report. Every step is in the journal.
The numbers the 守 page shows (disk, SSD, battery, temperature, snapshots) are written to health.json.
"""
import json
import time
from datetime import date
from pathlib import Path

from . import ai
from . import common as c
from . import conditions

MAX_FAILS = 2
# units that come and go by design or are ours to supervise elsewhere
SKIP_UNITS = ("ocarina-mamori", "ocarina-snake.service", "app-", "run-", "ocarina-mamori-ask")


# ── limits: never hammer the same repair ────────────────────────────────────────────────────
def _limits():
    lim = c.load_json(c.STATE / "limits.json", {}) or {}
    if lim.get("date") != date.today().isoformat():
        lim = {"date": date.today().isoformat(), "fails": {}, "escalated": {}, "notified": lim.get("notified", {}),
               "seen": lim.get("seen", {})}      # last diagnosis of each problem: kept across days (ESCALATE_EVERY)
    return lim


def _save_limits(lim):
    if not c.DRY:
        c.save_json(c.STATE / "limits.json", lim)


def allowed(rid):
    return _limits()["fails"].get(rid, 0) < MAX_FAILS


def failed(rid):
    lim = _limits()
    lim["fails"][rid] = lim["fails"].get(rid, 0) + 1
    _save_limits(lim)


def notify_once(rid, every_days, title, body, urgency="normal"):
    """A warning that would repeat (a worn battery) goes out at most once every N days."""
    lim = _limits()
    last = lim["notified"].get(rid, 0)
    if c.now() - last < every_days * c.DAY:
        return False
    lim["notified"][rid] = c.now()
    _save_limits(lim)
    c.notify(title, body, urgency, tag=rid)
    return True


ESCALATE_EVERY = 7 * 86400     # the same problem is diagnosed again after a week at most (it said Mesa twice in a row)


def escalate(rid, title, context):
    """Snake diagnoses each problem once a week at most; its verdict goes to the history (never runs anything)."""
    lim = _limits()
    if c.now() - (lim.get("seen", {}).get(rid) or 0) < ESCALATE_EVERY or lim["escalated"].get(rid):
        return None
    lim.setdefault("seen", {})[rid] = c.now()
    lim["escalated"][rid] = c.now()
    _save_limits(lim)
    d = ai.task("diagnose", context)
    if d:
        c.history("repair", f"Snake diagnosticó: {title}", d.get("summary_es", "")[:300], "attention",
                  cause=d.get("cause", ""), fix=d.get("fix", {}), suspicious=d.get("suspicious", False))
    return d


# ── facts ───────────────────────────────────────────────────────────────────────────────────
def root_health():
    f = c.fake().get("health")
    if f is not None:
        return f
    rc, out, _ = c.maint("health", timeout=60)
    try:
        return json.loads(out) if rc == 0 else {}
    except ValueError:
        return {}


def _read(p):
    try:
        return Path(p).read_text().strip()
    except OSError:
        return ""


def battery_health():
    for b in Path("/sys/class/power_supply").glob("BAT*"):
        full = _read(b / "energy_full") or _read(b / "charge_full")
        design = _read(b / "energy_full_design") or _read(b / "charge_full_design")
        try:
            return round(100 * int(full) / int(design))
        except (ValueError, ZeroDivisionError):
            continue
    return None


def cpu_temp():
    for h in Path("/sys/class/hwmon").glob("hwmon*"):
        if _read(h / "name") == "k10temp":
            try:
                return round(int(_read(h / "temp1_input")) / 1000)
            except ValueError:
                return None
    return None


def journal(unit, lines=60, user=True):
    argv = ["journalctl", "--no-pager", "-o", "short-iso", "-n", str(lines), "-u" if not user else "--user-unit", unit]
    return c.run(argv, timeout=20).stdout[-6000:]


# ── playbook rows ───────────────────────────────────────────────────────────────────────────
def row_shell(found):
    """Shell in safe mode or down → reset-failed + start; if it falls again → Snake + report (adapt.py decides
    about our own last compat commit)."""
    active = c.run(["systemctl", "--user", "is-active", "ocarinashell.service"], timeout=10).stdout.strip()
    safe = c.run(["systemctl", "--user", "is-active", "ocarinashell-safe.service"], timeout=10).stdout.strip()
    if c.fake().get("health_shell"):
        active, safe = c.fake()["health_shell"]
    if active == "active" and safe != "active":
        return
    rid = "shell"
    found.append({"id": rid, "title": "La shell está en modo seguro" if safe == "active" else "La shell no está activa"})
    if not allowed(rid):
        escalate(rid, "la shell no arranca", journal("ocarinashell.service", 120))
        return
    if c.DRY:
        c.say("[dry-run] systemctl --user reset-failed ocarinashell; systemctl --user start ocarinashell")
        return
    c.run(["systemctl", "--user", "reset-failed", "ocarinashell.service"], timeout=10)
    c.run(["systemctl", "--user", "start", "ocarinashell.service"], timeout=30)
    time.sleep(8)
    ok = c.run(["systemctl", "--user", "is-active", "ocarinashell.service"], timeout=10).stdout.strip() == "active"
    if ok:
        c.history("repair", "Reparado: la shell", "Vuelve a estar activa tras el modo seguro", "ok")
    else:
        failed(rid)
        c.history("repair", "La shell no arranca", "Sigue en modo seguro; Snake lo revisa", "fail")
        escalate(rid, "la shell no arranca", journal("ocarinashell.service", 120))


def _failed_user_units():
    f = c.fake().get("failed_user_units")
    if f is not None:
        return f
    r = c.run(["systemctl", "--user", "list-units", "--failed", "--plain", "--no-legend"], timeout=10)
    return [ln.split()[0] for ln in r.stdout.splitlines() if ln.split()]


def row_user_units(found):
    for u in _failed_user_units():
        if u.startswith(SKIP_UNITS) or u in ("ocarinashell.service", "ocarinashell-safe.service"):
            continue
        rid = f"unit:{u}"
        found.append({"id": rid, "title": f"Unidad fallida: {u}"})
        if not allowed(rid):
            if u.startswith("ocarina"):
                escalate(rid, f"la unidad {u} falla", journal(u))
            continue
        if c.DRY:
            c.say(f"[dry-run] systemctl --user restart {u}")
            continue
        c.run(["systemctl", "--user", "reset-failed", u], timeout=10)
        r = c.run(["systemctl", "--user", "restart", u], timeout=60)
        time.sleep(2)
        st = c.run(["systemctl", "--user", "is-failed", u], timeout=10).stdout.strip()
        if r.returncode == 0 and st != "failed":
            c.history("repair", f"Reparado: {u}", "Estaba fallida; reiniciada una vez y responde", "ok")
        else:
            failed(rid)
            c.history("repair", f"Sigue fallando: {u}", "Reiniciada sin éxito; queda en el informe", "fail")
            if u.startswith("ocarina") and not allowed(rid):
                escalate(rid, f"la unidad {u} falla", journal(u))


def row_system_units(found, h):
    for u in h.get("failedUnits", []):
        rid = f"sysunit:{u}"
        found.append({"id": rid, "title": f"Servicio del sistema fallido: {u}"})
        if not allowed(rid):
            continue
        rc, out, err = c.maint("unit-restart", u, timeout=120)
        if rc == 0:
            c.history("repair", f"Reparado: {u}", "Servicio del sistema reiniciado una vez", "ok")
        else:
            failed(rid)
            c.history("repair", f"Sigue fallando: {u}", (err or out).strip()[-200:], "fail")


def _own_cache_cleanup(days=30):
    """Our caches older than N days (thumbnails, blurred wallpapers, Snake's downloads). Never models or settings."""
    freed = 0
    cutoff = time.time() - days * c.DAY
    for p in c.CACHE.rglob("*"):
        try:
            if p.is_file() and not p.is_symlink() and p.stat().st_mtime < cutoff:
                freed += p.stat().st_size
                if not c.DRY:
                    p.unlink()
        except OSError:
            continue
    return freed


def row_disk(found, h):
    free = c.fake().get("disk_free", h.get("rootFreePercent"))
    if free is None or free >= 15:
        return
    rid = "disk"
    found.append({"id": rid, "title": f"Disco con poco espacio ({free} % libre)"})
    if not allowed(rid):
        return
    done = []
    rc, _, _ = c.maint("paccache", "2", timeout=600)
    done.append("caché de pacman a 2 versiones" if rc == 0 else "paccache falló")
    rc, _, _ = c.maint("journal-vacuum", timeout=300)
    done.append("journal a 500 MB" if rc == 0 else "journal-vacuum falló")
    freed = _own_cache_cleanup()
    done.append(f"cachés propias > 30 días ({freed / 2**20:.0f} MB)")
    if c.have("docker") and c.run(["docker", "info"], timeout=10).returncode == 0:
        # dangling images only; never volumes (the Windows disk of 船 Fune lives in one)
        if c.DRY:
            c.say("[dry-run] docker image prune -f")
        else:
            c.run(["docker", "image", "prune", "-f"], timeout=300)
        done.append("imágenes huérfanas de Docker")
    after = c.fake().get("disk_free_after", root_health().get("rootFreePercent", free) if not c.DRY else free)
    ok = after >= 15
    if not ok:
        failed(rid)
        notify_once("disk-low", 1, "Disco casi lleno", f"Queda un {after} % libre tras limpiar lo seguro. Revisa "
                    "tus descargas o vídeos grandes (Mamori no toca tus ficheros).", "critical")
    c.history("repair", "Limpieza por poco espacio" if ok else "Disco casi lleno",
              " · ".join(done) + f" · libre {free} % → {after} %", "ok" if ok else "attention")


def row_storage_errors(found, h):
    be = h.get("btrfsErrors") or 0
    nc = h.get("nvmeCriticalWarning") or 0
    nu = h.get("nvmePercentUsed") or 0
    if be or nc or nu >= 80:
        what = []
        if be:
            what.append(f"Btrfs registra {be} errores")
        if nc:
            what.append("el SSD tiene un aviso crítico (SMART)")
        if nu >= 80:
            what.append(f"el SSD lleva un {nu} % de su vida útil")
        found.append({"id": "storage", "title": "Errores de disco"})
        if notify_once("storage", 7, "Tu SSD necesita atención", "; ".join(what).capitalize() +
                       ". Haz una copia externa de lo importante cuanto antes.", "critical"):
            c.history("health", "Aviso urgente del disco", "; ".join(what), "attention")


def row_db_lock(found, h):
    if not h.get("orphanDbLock"):
        return
    found.append({"id": "dblck", "title": "Bloqueo de pacman huérfano"})
    rc, _, _ = c.maint("db-unlock", timeout=30)
    c.history("repair", "Reparado: bloqueo de pacman", "db.lck sin pacman en marcha, eliminado",
              "ok" if rc == 0 else "fail")


def row_clock(found):
    r = c.run(["timedatectl", "show", "-p", "NTP", "-p", "NTPSynchronized"], timeout=10)
    vals = dict(ln.split("=", 1) for ln in r.stdout.splitlines() if "=" in ln)
    if c.fake().get("ntp") is not None:
        vals = c.fake()["ntp"]
    if vals.get("NTP", "yes") == "yes" and vals.get("NTPSynchronized", "yes") == "yes":
        return
    rid = "clock"
    found.append({"id": rid, "title": "Reloj sin sincronizar"})
    if not allowed(rid):
        return
    rc, _, err = c.maint("time-sync", timeout=60)
    if rc == 0:
        c.history("repair", "Reparado: hora del sistema", "systemd-timesyncd activado", "ok")
    else:
        failed(rid)
        c.history("repair", "El reloj no se sincroniza", err.strip()[-200:], "fail")


def row_coredumps(found):
    if not c.have("coredumpctl") or c.fake().get("coredumps_off"):
        return
    # since the last cycle (at most 7 days): a laptop that stays closed for days must not hide what crashed before
    # (Nameraka's 4 crashes on 18/10 went unseen until 23/10 with «last 24 h», fase 17)
    last = int(c.status().get("lastRun") or 0)
    since = max(last - 3600, c.now() - 7 * 86400) if last else c.now() - 86400
    r = c.run(["coredumpctl", "list", f"--since=@{since}", "--json=short", "--no-pager"], timeout=20)
    try:
        dumps = json.loads(r.stdout or "[]")
    except ValueError:
        dumps = []
    dumps += c.fake().get("coredumps", [])
    # several programs dumping in the same few seconds = the session or the compositor went down (niri, the GPU
    # memory running out, a logout): not a bug of each program. Those are counted once, as a session event, and never
    # sent to Snake one by one (the first week blamed Mesa for the crashes of the fase-15 GTT exhaustion, D-092)
    def ts(d):
        t = d.get("time", 0) or 0
        return t / 1e6 if t > 1e12 else t
    times = sorted(ts(d) for d in dumps)
    def crowd(t):
        return sum(1 for u in times if abs(u - t) <= 10) >= 2 and \
            len({(x.get("exe") or x.get("comm")) for x in dumps if abs(ts(x) - t) <= 10}) >= 2
    by = {}
    for d in dumps:
        if ts(d) and crowd(ts(d)):
            continue
        exe = d.get("exe") or d.get("comm") or "?"
        by[exe] = by.get(exe, 0) + 1
    for exe, n in by.items():
        if n < 3:
            continue
        rid = f"core:{Path(exe).name}"
        found.append({"id": rid, "title": f"{Path(exe).name} se ha cerrado {n} veces desde la última revisión"})
        info = c.run(["coredumpctl", "info", "--no-pager", "-1", exe], timeout=30).stdout[-5000:]
        if escalate(rid, f"{Path(exe).name} se cierra solo ({n} veces desde la última revisión)", info) is None and \
                not ai.available():
            c.history("health", f"{Path(exe).name} se cierra solo", f"{n} volcados (coredumpctl)", "attention")


def row_battery(found):
    bh = battery_health()
    if bh is not None and bh < 70:
        found.append({"id": "battery", "title": f"Batería al {bh} % de su capacidad original"})
        if notify_once("battery-wear", 30, "Batería desgastada", f"Conserva un {bh} % de su capacidad original. "
                       "El límite de carga 75–80 % ya la protege; si baja de 60 %, toca cambiarla."):
            c.history("health", "Batería desgastada", f"{bh} % de la capacidad de diseño", "attention")
    t = cpu_temp()
    sh = conditions.shell_state() or {}
    idle = bool(sh.get("idle10"))
    if t is not None and t >= 75 and idle:
        found.append({"id": "temp", "title": f"CPU a {t} °C en reposo"})
        if notify_once("temp-idle", 14, "Temperatura alta en reposo", f"La CPU está a {t} °C sin hacer nada. "
                       "Puede ser polvo en el ventilador o una app en segundo plano (Mihari lo muestra)."):
            c.history("health", "Temperatura alta en reposo", f"{t} °C con el equipo inactivo", "attention")


def hikae_snapshots():
    """(count, newest timestamp) of snapper «home» (readable without root: ALLOW_USERS)."""
    r = c.run(["snapper", "--csvout", "--iso", "-c", "home", "list", "--columns", "number,date"], timeout=20)
    if r.returncode != 0:
        return None, 0
    n_snaps, last = 0, 0
    for line in r.stdout.splitlines()[1:]:
        try:
            n, d = line.split(",", 1)
            if int(n) > 0:
                n_snaps += 1
                last = max(last, int(time.mktime(time.strptime(d.strip()[:19], "%Y-%m-%d %H:%M:%S"))))
        except ValueError:
            continue
    return n_snaps, last


def row_hikae(found):
    """控 Hikae (D-070): the hourly snapshots of ~ must keep coming."""
    count, last = hikae_snapshots()
    if count is None:
        return
    last = c.fake().get("hikae_last", last)
    if c.now() - last > 2 * c.DAY:
        found.append({"id": "hikae", "title": "Las copias de 控 Hikae se han parado"})
        if notify_once("hikae", 3, "控 Copias paradas", "La última foto de tu carpeta personal es del "
                       f"{c.stamp(last) if last else '—'}. Revisa snapper-timeline.timer (ocarina backup status)."):
            c.history("health", "Copias de Hikae paradas", f"última: {c.stamp(last) if last else 'ninguna'}",
                      "attention")


def row_postupdate(found):
    """A transaction Ayoub made himself left the smoke tests red: report and diagnose (never roll back his own)."""
    pu = c.load_json(c.STATE_ROOT / "postupdate.json", {}) or {}
    if pu.get("ok", True) or pu.get("seenByMamori"):
        return
    found.append({"id": "postupdate", "title": "Pruebas de humo en rojo tras una actualización manual"})
    smoke = c.load_json(c.STATE_ROOT / "smoke.json", {}) or {}
    fails = [x.get("msg", "") for x in smoke.get("checks", []) if x.get("level") == "fail"]
    escalate("postupdate", "pruebas de humo fallidas tras " + str(pu.get("packages", "")),
             "Fallos:\n" + "\n".join(fails) + "\n\nJournal de la shell:\n" + journal("ocarinashell.service", 80))
    c.history("health", "Algo falla tras tu última actualización", " · ".join(fails)[:300], "attention")
    if not c.DRY:
        pu["seenByMamori"] = c.now()
        c.save_json(c.STATE_ROOT / "postupdate.json", pu)


# ── entry point ─────────────────────────────────────────────────────────────────────────────
def snapshot_numbers(h):
    out = {"disk": None, "diskUsed": None, "diskSize": None, "ssd": None, "battery": battery_health(),
           "cpuTemp": cpu_temp(), "snapshots": h.get("snapshots"), "snapshotsDays": h.get("snapshotsDays"),
           "btrfsErrors": h.get("btrfsErrors"), "at": c.now()}
    r = c.run(["df", "-B1", "--output=size,used", "/"], timeout=10)
    try:
        size, used = map(int, r.stdout.splitlines()[1].split())
        out.update(disk=round(100 * used / size), diskUsed=used, diskSize=size)
    except (IndexError, ValueError):
        pass
    if h.get("nvmePercentUsed") is not None:
        out["ssd"] = max(0, 100 - int(h["nvmePercentUsed"]))
    out["hikaeCount"], out["hikaeLast"] = hikae_snapshots()
    return out


def run():
    """→ list of problems found ({id, title}). Repairs happen inside, each with its verification."""
    found = []
    if c.fake().get("skipHealth"):
        return found
    h = root_health()
    for row in (lambda: row_shell(found), lambda: row_user_units(found), lambda: row_system_units(found, h),
                lambda: row_disk(found, h), lambda: row_storage_errors(found, h), lambda: row_db_lock(found, h),
                lambda: row_clock(found), lambda: row_coredumps(found), lambda: row_battery(found),
                lambda: row_hikae(found), lambda: row_postupdate(found)):
        try:
            row()
        except Exception as e:      # one broken row never stops the others (nor the cycle)
            c.jlog(f"salud: una comprobación falló: {e!r}")
    nums = snapshot_numbers(h)
    nums["problems"] = found
    if not c.DRY:
        c.save_json(c.STATE / "health.json", nums)
    return found
