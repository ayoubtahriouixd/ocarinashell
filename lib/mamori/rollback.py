"""守 Mamori — going back (docs/06 capa 5 › Reversión y Arranque fallido, fase 16 §8–9).

undo_last: the last pre/post pair of root (snap-pac), only if it is the transaction this cycle made (its pre is newer
than our «antes de actualizar» snapshot) — or, from the 守 page / `ocarina mamori rollback`, the last one whatever made
it (the helper still refuses anything but the last pair and keeps /boot coherent).
boot_failure: the boot mark says a new kernel did not reach the desktop → hold that kernel version and reinstall the
previous one from the cache (ocarina-maint downgrade).
"""
import json

from . import common as c
from . import verify


def last_pair():
    f = c.fake().get("last_pair")
    if f is not None:
        return f
    rc, out, _ = c.maint("last-pair", timeout=60)
    try:
        return json.loads(out) if rc == 0 else {}
    except ValueError:
        return {}


def undo_last(reason, after_snapshot=None, hold_names=(), hold_days=7):
    """→ (ok, detail)."""
    p = last_pair()
    if not p.get("pre") or not p.get("post"):
        return False, "no hay una transacción de pacman que deshacer"
    if after_snapshot is not None and p["pre"] <= after_snapshot:
        return False, f"la última transacción (#{p['pre']}) no es la de este ciclo"
    rc, out, err = c.maint("rollback", str(p["pre"]), str(p["post"]), timeout=1800)
    if rc != 0:
        detail = (err or out).strip()[-300:]
        c.history("rollback", "No se pudo deshacer la actualización", detail, "fail")
        c.notify("No pude deshacer la actualización", detail + "\nTienes el snapshot en el menú de Limine.",
                 "critical", tag="rollback")
        return False, detail
    for n in hold_names:
        c.set_hold(n, hold_days, reason[:200], "auto", version="")
    ok, fails = verify.smoke(not verify.locked())
    detail = f"snapshot #{p['pre']}..#{p['post']} · pruebas {'✓' if ok else '✗ ' + '; '.join(fails[:2])}"
    c.history("rollback", "Actualización deshecha", f"{reason} · {detail}", "hold" if ok else "fail",
              pre=p["pre"], post=p["post"])
    return ok, detail


def boot_failure():
    """Read the boot mark's alert (ocarina-bootmark) once → hold + downgrade. → True if it acted."""
    path = c.STATE_ROOT / "boot/alert.json"
    if c.fake().get("boot_alert") is not None:
        alert = c.fake()["boot_alert"]
    else:
        alert = c.load_json(path)
    if not alert or alert.get("handledByMamori"):
        return False
    kernel, version = alert.get("kernel", ""), alert.get("version", "")
    if not kernel:
        return False
    c.set_hold(kernel, 30, f"{version} no arrancó ({alert.get('kind')})", "auto", version=version)
    cur = (c.run(["pacman", "-Q", kernel], timeout=10).stdout.split() + ["", ""])[1]
    if c.fake().get("boot_alert") is not None:
        cur = version
    if cur != version:
        rc, out, err = 0, "", ""       # already gone (Ayoub or an earlier cycle): only the hold is new
    else:
        rc, out, err = c.maint("downgrade", kernel, timeout=1800)
    ok = rc == 0
    detail = f"{kernel} {version} retenido 30 días; " + ("vuelto a la versión anterior de la caché"
                                                          if ok else "no pude bajarlo: " + (err or out).strip()[-160:])
    c.history("rollback", f"Kernel retenido: {kernel} {version}", detail, "hold" if ok else "fail")
    c.notify("Kernel retenido", detail + ("\nEn tu próximo reinicio arrancará el kernel anterior." if ok else ""),
             "normal" if ok else "critical", tag="kernel")
    if not c.DRY and c.fake().get("boot_alert") is None:
        alert["handledByMamori"] = c.now()
        c.save_json(path, alert)
    return True
