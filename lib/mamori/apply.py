"""守 Mamori — applying a decided plan (docs/06 capa 6 › Ciclo 5, fase 16 §7).

snapshot «mamori: antes de actualizar» → ocarina-maint upgrade (pacman -Syu, kernels held if needed) → smoke tests of
the repo batch (verify.py; a failure is adapted or rolled back before anything else lands, so the transaction to undo
is always the last one) → AUR packages, built by root in a sandbox (ocarina-maint aur-build) → user services that run
on what changed → reboot flag if the kernel, systemd, glibc, Mesa or firmware changed.
"""
import re

from . import common as c

FLAG = c.RUNTIME / "update-running"      # ocarina-postupdate leaves the smoke tests to us while this exists


def mark_running(on):
    if c.DRY:
        return
    c.RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    if on:
        FLAG.touch()
    else:
        FLAG.unlink(missing_ok=True)


def download():
    rc, out, err = c.maint("download", timeout=3600)
    return rc == 0, (err or out).strip()[-300:]


def snapshot(desc="antes de actualizar"):
    rc, out, err = c.maint("snapshot", desc, timeout=120)
    if c.DRY:
        return 0
    try:
        return int(out.strip().splitlines()[-1]) if rc == 0 else None
    except (ValueError, IndexError):
        return None


def upgrade(kernel_holds):
    args = ["upgrade"]
    for k in kernel_holds:
        args += ["--hold", k]
    rc, out, err = c.maint(*args, timeout=3 * 3600)
    return rc, (err or out).strip()[-600:]


def aur_build(decisions):
    """→ (built names, failed [(name, why)])."""
    built, failed = [], []
    for d in decisions:
        if not d.get("approved") or not re.fullmatch(r"[0-9a-f]{40}", d.get("commit", "")):
            continue
        rc, out, err = c.maint("aur-build", d["name"], d["commit"], timeout=2 * 3600)
        if rc == 0:
            built.append(d["name"])
        else:
            failed.append((d["name"], (err or out).strip()[-200:] or f"código {rc}"))
    return built, failed


def firmware_stage(fw):
    """Non-system devices only (the helper refuses BIOS/EC); they apply on the next reboot on AC."""
    staged = []
    for d in fw:
        if d.get("system") or not re.fullmatch(r"[0-9a-f]{40}", d.get("id", "")):
            continue
        rc, _, _ = c.maint("fw-stage", d["id"], timeout=1800)
        if rc == 0:
            staged.append(d["name"])
    return staged


def needs_reboot(names):
    return [n for n in names if re.match(c.REBOOT_RE, n)]


def set_reboot_pending(why):
    """Dengen shows «Actualizar y reiniciar» and Obi the 新 hanko while this file exists (removed after a boot)."""
    if c.DRY:
        return
    f = c.STATE / "reboot-pending"
    data = c.load_json(f, {}) or {}
    data.setdefault("since", c.now())
    data["why"] = sorted(set(data.get("why", [])) | set(why))
    c.save_json(f, data)


def clear_reboot_pending_if_booted():
    f = c.STATE / "reboot-pending"
    data = c.load_json(f)
    if not data:
        return
    try:
        btime = int(next(ln.split()[1] for ln in open("/proc/stat") if ln.startswith("btime")))
    except (OSError, StopIteration, ValueError):
        return
    if btime > data.get("since", 0) and not c.DRY:
        f.unlink(missing_ok=True)
        c.history("info", "Reinicio hecho", "El sistema ya usa lo que se actualizó", "ok")


def restart_user_services(names):
    """Audio and portals restart while Ayoub is away (never during a call: conditions checked the microphone)."""
    units = []
    if any(re.match(r"^(pipewire.*|wireplumber)$", n) for n in names):
        units += ["pipewire.service", "pipewire-pulse.service", "wireplumber.service"]
    if any(n.startswith("xdg-desktop-portal") for n in names):
        units += ["xdg-desktop-portal.service"]
    for u in units:
        if c.DRY:
            c.say(f"[dry-run] systemctl --user try-restart {u}")
        else:
            c.run(["systemctl", "--user", "try-restart", u], timeout=60)
    return units


def shell_base_changed(names):
    return any(re.match(c.SHELL_BASE_RE, n) for n in names)
