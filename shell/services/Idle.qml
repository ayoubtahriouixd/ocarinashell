pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Idle policy (ext-idle-notify through IdleMonitor; no polling). Profiles from Settings › idle, AC or battery:
//   AC: dim 4 min · lock 5 · screens off 6 · suspend never — battery: 2 · 3 · 4 · 15 (minutes, 0 = never).
// Dim = every screen to ≤ 30 % (Brightness.dimAll), each restored to its own value on the first input.
// Inhibitors are respected (videos, the 醒 "Despierto" switch). `longIdle` (≥ 15 min, inhibitors ignored) is the
// signal 守 Mamori uses to run its maintenance opportunistically (phase 16).
// Screens off while locked is Kagi's own business (30 s, services/Lock).
// The IdleMonitors live in backends/IdleBackend.qml (capa 3.1); without it nothing dims, locks or suspends on its own
// and Health says why.
Singleton {
    id: root

    property QtObject backend: null
    property string error: ""
    readonly property bool available: backend !== null
    property bool inhibit: false
    readonly property var profile: Power.onBattery ? Settings.data.idle.battery : Settings.data.idle.ac
    readonly property bool longIdle: backend?.longIdle ?? false
    readonly property bool idle10: backend?.idle10 ?? false          // 守 Mamori's «Ayoub is away»
    readonly property bool lockActive: Lock.active

    function seconds(minutes: real): real {
        const m = Number(minutes) || 0;
        return m > 0 ? Math.max(5, m * 60) : 0;
    }

    function toggleInhibit(): void {
        inhibit = !inhibit;
        Osd.show("info", 0, inhibit ? "Despierto: no se suspenderá" : "Despierto desactivado", inhibit ? "coffee" : "bedtime");
    }

    function status(): string {
        return JSON.stringify({ onBattery: Power.onBattery, profile: profile, inhibit: inhibit,
                                idle: { dim: dimIdle, lock: lockIdle, screenOff: offIdle, suspend: sleepIdle,
                                        long: longIdle },
                                dimmed: Brightness.dimmed });
    }

    readonly property string key: [profile.dim, profile.lock, profile.screenOff, profile.suspend].join(",")
    property bool dimIdle: false
    property bool lockIdle: false
    property bool offIdle: false
    property bool sleepIdle: false

    // edges reported by the backend's monitors
    function dimEdge(idle: bool): void {
        dimIdle = idle;
        if (idle)
            Brightness.dimAll();
        else
            Brightness.undim();
    }
    function lockEdge(idle: bool): void {
        lockIdle = idle;
        if (idle)
            Lock.lock();
    }
    function offEdge(idle: bool): void {
        offIdle = idle;
        if (idle)
            Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
    }
    // ocarina-sleep.service locks first (before-sleep)
    function sleepEdge(idle: bool): void {
        sleepIdle = idle;
        if (idle)
            Quickshell.execDetached(["systemctl", "suspend"]);
    }

    Component.onCompleted: {
        const c = Qt.createComponent("backends/IdleBackend.qml");
        if (c.status === Component.Ready) {
            backend = c.createObject(root, { owner: root });
        } else {
            error = c.errorString();
            Health.fail("Inactividad (IdleMonitor)", error);
        }
    }
}
