pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Battery (UPower display device) and power profile (power-profiles-daemon). Event driven.
// The UPower types live in backends/PowerBackend.qml (capa 3.1: a singleton that imports a sensitive module takes
// the whole `qs.services` import down with it when that module changes).
Singleton {
    id: root

    property QtObject backend: null
    property string error: ""
    readonly property bool available: backend?.ready ?? false
    readonly property bool hasBattery: available && (backend?.isLaptopBattery ?? false)
    readonly property real percent: backend?.percentage ?? 0        // 0–1
    readonly property bool charging: backend?.charging ?? false
    readonly property bool full: backend?.full ?? false
    readonly property bool discharging: backend?.discharging ?? false
    readonly property bool onBattery: backend?.onBattery ?? false
    readonly property real timeToEmpty: backend?.timeToEmpty ?? 0
    readonly property real timeToFull: backend?.timeToFull ?? 0
    readonly property real changeRate: backend?.changeRate ?? 0     // W, signed as UPower reports it
    readonly property string nativePath: backend?.nativePath ?? ""  // BAT0…
    readonly property bool low: onBattery && percent <= Settings.data.power.lowBattery / 100

    // ── mean power of the last 60 s (忍 Shinobi toast): UPower publishes the rate on its own; we only keep the
    // values it sends (no polling of our own). 0 when not discharging.
    property var rates: []                // [{ t, w }]
    Connections {
        target: root.backend
        ignoreUnknownSignals: true
        function onChangeRateChanged() { root.logRate(); }
    }
    function logRate(): void {
        const now = Date.now();
        rates = rates.filter(x => now - x.t <= 60000).concat([{ t: now, w: Math.abs(backend?.changeRate ?? 0) }]);
    }
    function meanWatts(): real {
        if (!discharging)
            return 0;
        const now = Date.now();
        const r = rates.filter(x => now - x.t <= 60000 && x.w > 0);
        return r.length > 0 ? r.reduce((a, x) => a + x.w, 0) / r.length : Math.abs(backend?.changeRate ?? 0);
    }
    // hours left at that mean (0 = unknown)
    function hoursAt(w: real): real {
        const e = backend?.energy ?? 0;
        return w > 0.3 && e > 0 ? e / w : 0;
    }

    // "power-saver" | "balanced" | "performance" (kanji-ui.json keys)
    readonly property string profile: backend?.profile ?? "balanced"

    function setProfile(id: string, quiet: bool): void {
        if (!backend)
            return;
        backend.setProfile(id);
        if (quiet)
            return;
        const p = Glossary.profile(id);
        Osd.show("profile", 1, p.kanji + " " + p.es, id === "performance" ? "bolt" : id === "power-saver" ? "eco" : "balance");
    }
    function cycleProfile(): void {
        const order = ["power-saver", "balanced", "performance"];
        setProfile(order[(order.indexOf(profile) + 1) % 3], false);
    }

    Component.onCompleted: {
        const c = Qt.createComponent("backends/PowerBackend.qml");
        if (c.status === Component.Ready) {
            backend = c.createObject(root);
        } else {
            error = c.errorString();
            Health.fail("Batería (Quickshell.Services.UPower)", error);
        }
    }
}
