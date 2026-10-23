"""守 Mamori — periodic maintenance (docs/06 capa 6 › Mantenimiento periódico), always under the cycle's conditions.

Weekly: pacman cache (3 versions), orphans (report only), firmware metadata, `claude update` if installed.
Monthly: btrfs scrub (on AC), mirrors, Neovim plugins (sandbox → health → fast-forward, bin/ocarina-nvim-health),
船 Fune (image/WinApps + Windows Update window, only if Fune is set up), 蛇 Snake models not evaluated yet, 控 Hikae
integrity (ocarina backup check). Each job remembers when it last ran (periodic.json) and fails alone.
"""
import json
import os

from . import common as c

WEEK, MONTH = 7 * c.DAY, 30 * c.DAY


def _due(state, job, every):
    return c.now() - state.get(job, {}).get("at", 0) >= every


def _done(state, job, ok, detail=""):
    state[job] = {"at": c.now(), "ok": ok, "detail": detail[-300:]}


def j_paccache():
    rc, _, err = c.maint("paccache", "3", timeout=900)
    return rc == 0, "caché de pacman: 3 versiones" if rc == 0 else err


def j_history():
    """history.jsonl keeps its last 2000 events (the 守 page reads the whole file on each change)."""
    f = c.STATE / "history.jsonl"
    try:
        lines = f.read_text(encoding="utf-8").splitlines()
    except OSError:
        return True, "sin historial"
    if len(lines) <= 2000 or c.DRY:
        return True, f"{len(lines)} eventos"
    tmp = f.with_name(f.name + ".tmp")
    tmp.write_text("\n".join(lines[-2000:]) + "\n", encoding="utf-8")
    os.replace(tmp, f)
    return True, f"historial recortado a 2000 de {len(lines)}"


def j_orphans():
    r = c.run(["pacman", "-Qdtq"], timeout=60)
    orph = r.stdout.split()
    if orph:
        c.history("periodic", f"{len(orph)} paquetes huérfanos", ", ".join(orph[:12]) +
                  (" …" if len(orph) > 12 else "") + " (solo informe: no se borra nada)", "info")
    return True, f"{len(orph)} huérfanos"


def j_fw_refresh():
    if not c.have("fwupdmgr"):
        return True, "sin fwupd"
    rc, _, err = c.maint("fw-refresh", timeout=600)
    return rc == 0, "metadatos de firmware al día" if rc == 0 else err


def j_claude():
    if not c.have("claude"):
        return True, "Claude Code no está instalado"
    r = c.run(["claude", "update"], timeout=600)
    return r.returncode == 0, (r.stdout or r.stderr).strip()[-200:]


def j_scrub():
    if not c.on_ac():
        return None, "espera al cargador"
    rc, _, err = c.maint("scrub", "start", timeout=120)
    return rc == 0, "btrfs scrub en marcha (IO en reposo)" if rc == 0 else err


def j_mirrors():
    if not c.have("cachyos-rate-mirrors"):
        return True, "sin cachyos-rate-mirrors"
    rc, _, err = c.maint("mirrors", timeout=1800)
    return rc == 0, "mirrors ordenados por velocidad" if rc == 0 else err


def j_nvim():
    tool = c.BIN / "ocarina-nvim-health"
    if not tool.exists() or not c.have("nvim"):
        return True, "sin Neovim"
    if c.DRY:
        r = c.run([str(tool), "update", "--json"], timeout=1800)
    else:
        r = c.run([str(tool), "update", "--apply", "--json"], timeout=1800)
    # the tool prints indented JSON (many lines): the object starts at the first «{» (fase 17: reading only the last
    # line, «}», made every run «pruebas en rojo»)
    out = r.stdout.strip()
    try:
        res = json.loads(out[out.index("{"):])
    except ValueError:
        res = {}
    ok = r.returncode == 0 and res.get("ok", False)
    detail = ((f"{len(res.get('changes', []))} plugins cambiados" if res.get("changes") else "sin cambios") if ok
              else "; ".join(res.get("problems", [])[:2]) or r.stderr.strip()[-200:])
    c.history("periodic", "Plugins de Neovim " + ("actualizados" if ok else "sin cambios (pruebas en rojo)"),
              str(detail), "ok" if ok else "attention")
    return ok, str(detail)


def j_fune():
    fune = c.BIN / "ocarina-fune"
    cfg = c.DATA / "fune"
    if not fune.exists() or not cfg.exists():
        return True, "Fune no está configurado"
    if not c.on_ac():
        return None, "espera al cargador"
    r = c.run([str(fune), "update"], timeout=3600)
    ok = r.returncode == 0
    m = c.run([str(fune), "maintenance"], timeout=2 * 3600)
    ok = ok and m.returncode == 0
    detail = (r.stdout + m.stdout).strip()[-300:]
    c.history("periodic", "船 Fune: mantenimiento" + ("" if ok else " con avisos"), detail, "ok" if ok else "attention")
    return ok, detail


def j_snake_models(state):
    """Models downloaded but never evaluated by Mamori: evaluate one per month and switch only if it wins (score
    higher, 100 % valid JSON and 100 % injection cases). Pulling GBs stays Ayoub's call (`ocarina snake models pull`)."""
    snake = str(c.BIN / "ocarina-snake")
    r = c.run([snake, "models", "list", "--json"], timeout=30)
    try:
        models = json.loads(r.stdout)
    except ValueError:
        return True, "sin catálogo"
    scores = state.setdefault("snake-scores", {})
    for m in models:                # evaluated in phase 15 (docs/SNAKE.md) or later: the catalogue keeps the score
        if m.get("eval"):
            scores.setdefault(m["id"], m["eval"].get("score"))
    todo = [m["id"] for m in models if m.get("present") and m["id"] not in scores]
    if not todo:
        return True, "ningún modelo nuevo que evaluar"

    cur = next((m["id"] for m in models if m.get("default")), "")
    r = c.run([snake, "eval", "--model", cur, "--compare", todo[0], "--json"], timeout=4 * 3600)
    try:
        res = json.loads(r.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return False, "la evaluación no terminó"
    wins = bool(res.get("candidateWins"))
    scores[todo[0]] = res.get("candidate", {}).get("score")
    scores[cur] = res.get("current", {}).get("score")
    detail = f"{todo[0]}: {scores[todo[0]]} % frente a {cur}: {scores[cur]} %"
    if wins and not c.DRY:
        f = c.CONFIG / "ocarinashell/settings.json"
        s = c.load_json(f, {}) or {}
        s.setdefault("snake", {})["model"] = todo[0]
        c.save_json(f, s)
    c.history("periodic", f"蛇 Snake evaluó {todo[0]}" + (": nuevo modelo" if wins else ""), detail,
              "ok" if wins else "info")
    return True, detail


def j_hikae():
    r = c.run([str(c.BIN / "ocarina-backup"), "check"], timeout=300)
    if r.returncode != 0:
        c.notify("控 Copias con problemas", r.stdout.strip()[-200:], "normal", tag="hikae")
        c.history("periodic", "控 Hikae: comprobación con fallos", r.stdout.strip()[-200:], "attention")
    return r.returncode == 0, r.stdout.strip()[-200:]


JOBS = [("history", WEEK, j_history), ("paccache", WEEK, j_paccache), ("orphans", WEEK, j_orphans), ("fw-refresh", WEEK, j_fw_refresh),
        ("claude-update", WEEK, j_claude), ("scrub", MONTH, j_scrub), ("mirrors", MONTH, j_mirrors),
        ("nvim", MONTH, j_nvim), ("fune", MONTH, j_fune), ("snake-models", MONTH, j_snake_models),
        ("hikae", MONTH, j_hikae)]


def run(only=None, force=False):
    if c.sim() and not c.fake().get("periodic"):
        return []
    state = c.load_json(c.STATE / "periodic.json", {}) or {}
    done = []
    for name, every, fn in JOBS:
        if only and name != only:
            continue
        if not force and not _due(state, name, every):
            continue
        try:
            ok, detail = fn(state) if name == "snake-models" else fn()
        except Exception as e:        # one job never stops the others
            ok, detail = False, repr(e)
        if ok is None:                # not now (battery): try again next cycle
            continue
        _done(state, name, bool(ok), str(detail))
        done.append((name, ok, detail))
        c.jlog(f"periódico {name}: {'ok' if ok else 'fallo'} · {detail}")
    if not c.DRY:
        c.save_json(c.STATE / "periodic.json", state)
    return done
