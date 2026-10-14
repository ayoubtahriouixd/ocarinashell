#!/usr/bin/env python3
"""Boot the REAL Limine in QEMU/OVMF with a given limine.conf and take a screenshot of its menu.

Nothing on the host's /boot is touched: a throwaway FAT ESP image is built in a temp dir.
  python3 tools/limine-preview.py conf out.png --asset assets/boot/limine/ocarinashell-limine-dark.png=ocarinashell-limine.png
Defaults are CachyOS paths (limine, edk2-ovmf); needs qemu-system-x86_64, mtools and dosfstools.
The config should use `timeout: no`, otherwise Limine boots the (missing) kernel before the screenshot.
Standard library only (no Pillow needed).
"""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time

EFI = ["/usr/share/limine/BOOTX64.EFI"]
OVMF_CODE = ["/usr/share/edk2/x64/OVMF_CODE.4m.fd", "/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"]
OVMF_VARS = ["/usr/share/edk2/x64/OVMF_VARS.4m.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd", "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"]


def first(paths, what):
    for p in paths:
        if os.path.exists(p):
            return p
    sys.exit(f"{what} not found (tried: {', '.join(paths)})")


def run(*cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def qmp(sock_path, *cmds):
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(20)
    s.connect(sock_path)
    f = s.makefile("rw")
    json.loads(f.readline())                        # greeting
    out = []
    for c in ({"execute": "qmp_capabilities"},) + cmds:
        f.write(json.dumps(c) + "\n")
        f.flush()
        while True:
            r = json.loads(f.readline())
            if "return" in r or "error" in r:
                out.append(r)
                break
    s.close()
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("conf")
    ap.add_argument("out")
    ap.add_argument("--asset", action="append", default=[], help="file[=name-on-ESP] copied to the ESP root")
    ap.add_argument("--efi", default=None)
    ap.add_argument("--ovmf-code", default=None)
    ap.add_argument("--ovmf-vars", default=None)
    ap.add_argument("--res", default="2880x1800")
    ap.add_argument("--wait", type=float, default=60, help="max seconds to wait for a stable menu")
    a = ap.parse_args()
    efi = a.efi or first(EFI, "Limine BOOTX64.EFI")
    code = a.ovmf_code or first(OVMF_CODE, "OVMF code")
    vars_src = a.ovmf_vars or first(OVMF_VARS, "OVMF vars")
    xres, yres = a.res.split("x")
    for tool in ("qemu-system-x86_64", "mkfs.fat", "mcopy", "mmd"):
        if not shutil.which(tool):
            sys.exit(f"missing tool: {tool}")
    with tempfile.TemporaryDirectory(prefix="limine-preview-") as td:
        td = pathlib.Path(td)
        esp, vars_ = td / "esp.img", td / "vars.fd"
        shutil.copy(vars_src, vars_)
        run("mkfs.fat", "-C", "-F", "32", str(esp), "131072")
        run("mmd", "-i", str(esp), "::/EFI", "::/EFI/BOOT")
        run("mcopy", "-i", str(esp), efi, "::/EFI/BOOT/BOOTX64.EFI")
        run("mcopy", "-i", str(esp), a.conf, "::/limine.conf")
        for item in a.asset:
            src, _, name = item.partition("=")
            run("mcopy", "-i", str(esp), src, f"::/{name or os.path.basename(src)}")
        sock = str(td / "qmp.sock")
        qemu = subprocess.Popen([
            "qemu-system-x86_64", "-machine", "q35", "-m", "512", "-nodefaults", "-no-user-config",
            "-drive", f"if=pflash,format=raw,readonly=on,file={code}", "-drive", f"if=pflash,format=raw,file={vars_}",
            "-drive", f"format=raw,file={esp},if=virtio",
            "-device", f"VGA,xres={xres},yres={yres},vgamem_mb=64,edid=on",
            "-display", "none", "-qmp", f"unix:{sock},server,nowait"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            t0, last, stable, size = time.time(), None, 0, None
            shot = td / "shot.png"
            while time.time() - t0 < a.wait:
                time.sleep(2)
                if not os.path.exists(sock):
                    continue
                r = qmp(sock, {"execute": "screendump", "arguments": {"filename": str(shot), "format": "png"}})[-1]
                if "error" in r or not shot.exists():
                    continue
                data = shot.read_bytes()
                size = struct.unpack(">II", data[16:24]) if data[:8] == b"\x89PNG\r\n\x1a\n" else None
                sig = hashlib.sha1(data).hexdigest()
                # a black or firmware frame compresses to a few KB; the themed menu is hundreds of KB
                ready = size == (int(xres), int(yres)) and len(data) > 60_000
                stable = stable + 1 if (sig == last and ready) else 0
                last = sig
                if stable >= 1:
                    shutil.copy(shot, a.out)
                    print(f"{a.out}: {size[0]}×{size[1]} after {time.time() - t0:.0f} s")
                    return
            sys.exit(f"Limine menu did not settle in {a.wait:.0f} s (last frame {size or '—'})")
        finally:
            qemu.kill()
            qemu.wait()


if __name__ == "__main__":
    main()
