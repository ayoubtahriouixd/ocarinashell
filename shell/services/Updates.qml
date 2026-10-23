pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 新 What the bar's update hanko shows (fase 14; 守 Mamori feeds it from phase 16). With Mamori active the hanko only
// appears when a reboot waits (updates are Mamori's business; the count comes from its status, no own check):
// - pending: repo updates from `checkupdates` (its own temporary sync DB: the system's is never touched), every 6 h,
//   only on AC and outside 忍 Shinobi; recounted without the network (--nosync) right after any pacman transaction
// - rebootNeeded: the running kernel is not the installed one (a kernel update waits for the next boot), or Mamori's
//   reboot flag (Dengen.rebootPending)
Singleton {
    id: root

    readonly property bool available: Tools.has("checkupdates")
    property string error: ""
    property int pending: 0
    property var critical: []            // names, docs/06 capa 6 › Clasificación
    property bool kernelChanged: false
    readonly property bool rebootNeeded: kernelChanged || Dengen.rebootPending
    readonly property int pendingShown: Mamori.active ? (Mamori.st.pending?.repo ?? 0) : pending
    // with Mamori active: a reboot, or something of Mamori's that needs Ayoub (a failure, a rollback, a BIOS to approve)
    readonly property bool mamoriCalls: Mamori.active && (Mamori.tone === "warn" || Mamori.attention > 0)
    readonly property bool show: rebootNeeded || (!Mamori.active && pending > 0) || mamoriCalls
    readonly property var criticalShown: Mamori.active ? (Mamori.st.pending?.critical ?? []) : critical
    property double checkedAt: 0
    readonly property bool allowed: available && !Power.onBattery && !Modes.shinobi && !Mamori.active
    readonly property var criticalRe: /^(linux.*|mesa|lib32-mesa|vulkan-radeon|niri|quickshell|qt6-.*|systemd|systemd-libs|glibc|pipewire.*|wireplumber|linux-firmware.*|limine|plymouth|power-profiles-daemon|scx-.*|freerdp|docker|podman)$/

    readonly property string summary: {
        const parts = [];
        if (pendingShown > 0)
            parts.push(pendingShown + (pendingShown === 1 ? " actualización" : " actualizaciones")
                       + (criticalShown.length > 0 ? " (críticas: " + criticalShown.slice(0, 3).join(", ") + (criticalShown.length > 3 ? "…" : "") + ")" : ""));
        if (mamoriCalls)
            parts.push("守 " + Mamori.headline.toLowerCase());
        if (rebootNeeded)
            parts.push(kernelChanged ? "kernel nuevo: reinicia cuando te venga bien" : "reinicio pendiente");
        return parts.join(" · ");
    }

    function refresh(sync: bool): void {
        if (!available || count.running)
            return;
        count.command = sync ? ["checkupdates"] : ["checkupdates", "--nosync"];
        count.running = true;
        kernel.running = true;
    }

    Process {
        id: count
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(l => l.trim() !== "").map(l => l.split(" ")[0]);
                root.pending = names.length;
                root.critical = names.filter(n => root.criticalRe.test(n));
                root.checkedAt = Date.now();
            }
        }
        // 0 = updates, 2 = none, 1 = error (no network: keep the last count)
        onExited: code => {
            if (code === 2) {
                root.pending = 0;
                root.critical = [];
                root.checkedAt = Date.now();
            }
            root.error = code === 1 ? "checkupdates falló (¿sin red?)" : "";
        }
    }
    // the package that owns the running kernel, and whether pacman has a different version of it now
    Process {
        id: kernel
        command: ["sh", "-c", 'r=$(uname -r); p=$(cat "/usr/lib/modules/$r/pkgbase" 2>/dev/null) || exit 0; '
                 + 'v=$(pacman -Q "$p" 2>/dev/null | cut -d" " -f2) || exit 0; case "$r" in "$v"*) echo same ;; *) echo changed ;; esac']
        stdout: StdioCollector {
            onStreamFinished: root.kernelChanged = text.trim() === "changed"
        }
    }
    Timer {
        // first look 2 min after login (never compete with the session start), then every 6 h
        interval: root.checkedAt === 0 ? 2 * 60 * 1000 : 6 * 3600 * 1000
        repeat: true
        running: root.allowed
        onTriggered: root.refresh(true)
    }
    FileView {
        // written by the pacman hook at the end of every transaction
        path: "/var/lib/ocarinashell/needs-check"
        printErrors: false
        watchChanges: true
        onFileChanged: root.refresh(false)
    }
    // at start (a shell restart is exactly what follows an update): count from checkupdates' own temporary DB of the
    // last online check, no network; nothing there yet → the timer's first online check in 2 min
    Component.onCompleted: refresh(false)
}
