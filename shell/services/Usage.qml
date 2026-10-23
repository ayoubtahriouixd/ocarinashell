pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Live CPU, GPU and RAM use for the bar: a ring with the % inside each (Ayoub, fase 14). Same formulas as
// bin/ocarina-mihari (btop's defaults): CPU from /proc/stat deltas, RAM = total − available, GPU = amdgpu's
// gpu_busy_percent. Read every 2 s with FileView (no process), values rounded to 2 % so the rings only repaint when
// something really changes. Nothing runs in 忍 Shinobi, with the screen locked or off, or with bar.showUsage off.
Singleton {
    id: root

    readonly property bool wanted: Settings.data.bar.showUsage && !Modes.shinobi && !Lock.active && !Idle.offIdle
    property real cpu: 0                    // 0–1
    property real gpu: 0
    property real ram: 0
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0
    property string gpuPath: ""
    readonly property bool hasGpu: gpuPath !== ""
    readonly property bool available: true  // /proc is always there; the GPU ring hides without amdgpu

    property var last: null                 // [busy, total] jiffies of the previous sample
    function step(v: real): real {
        return Math.round(Math.max(0, Math.min(1, v)) * 50) / 50;
    }
    function sample(): void {
        stat.reload();
        const l = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (l.length >= 4) {
            const idle = l[3] + (l[4] || 0), total = l.reduce((a, b) => a + b, 0);
            if (last && total > last[1])
                cpu = step(1 - (idle - last[0]) / (total - last[1]));
            last = [idle, total];
        }
        mem.reload();
        const m = {};
        for (const line of mem.text().split("\n")) {
            const p = line.split(/:\s+/);
            if (p.length === 2)
                m[p[0]] = parseInt(p[1]);
        }
        if (m.MemTotal > 0) {
            ram = step(1 - (m.MemAvailable ?? 0) / m.MemTotal);
            ramTotalGiB = m.MemTotal / 1048576;
            ramUsedGiB = (m.MemTotal - (m.MemAvailable ?? 0)) / 1048576;
        }
        if (hasGpu) {
            busy.reload();
            gpu = step(parseInt(busy.text()) / 100 || 0);
        }
    }
    onWantedChanged: if (!wanted) last = null      // a stale delta after a pause would be one wrong sample

    FileView { id: stat; path: "/proc/stat"; blockLoading: true; printErrors: false }
    FileView { id: mem; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
    FileView { id: busy; path: root.gpuPath; blockLoading: true; printErrors: false }
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.gpuPath = text.trim()
        }
    }
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.wanted
        onTriggered: root.sample()
    }
}
