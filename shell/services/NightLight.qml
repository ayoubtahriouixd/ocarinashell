pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 夜 Night light through wlsunset in ocarina-nightlight.service (arguments in an env file the unit reads).
// Modes (display.nightLight.mode): off · auto (sunset/sunrise from the weather location) · schedule (from/to) ·
// manual (always warm). Temperature: display.nightLight.temp.
Singleton {
    id: root

    readonly property bool available: Tools.has("wlsunset")
    property string error: ""
    readonly property var cfg: Settings.data.display.nightLight
    readonly property string mode: cfg.mode
    readonly property bool on: mode !== "off"
    readonly property string subtitle: mode === "off" ? "Desactivada"
        : mode === "manual" ? "Activa · " + cfg.temp + " K"
        : mode === "auto" ? "Automática · " + Kisetsu.sunsetText + "–" + Kisetsu.sunriseText
        : "Hasta las " + cfg.to

    function args(): string {
        const t = Math.max(1900, Math.min(6000, cfg.temp));
        const hi = 6500;
        switch (mode) {
        case "auto": return "-t " + t + " -T " + hi + " -l " + Settings.data.weather.lat + " -L " + Settings.data.weather.lon;
        case "schedule": return "-t " + t + " -T " + hi + " -S " + cfg.to + " -s " + cfg.from;
        default: return "-t " + t + " -T " + (t + 1) + " -S 23:59 -s 00:00 -d 60";   // manual: always night
        }
    }

    function apply(): void {
        if (mode !== "off" && !available) {
            fail("falta wlsunset");
            return;
        }
        if (mode === "off") {
            run(["systemctl", "--user", "stop", "ocarina-nightlight.service"]);
            return;
        }
        const text = "OCARINA_NL_ARGS=" + args() + "\n";
        if (text === env.text())
            run(["systemctl", "--user", "start", "ocarina-nightlight.service"]);   // no-op if already running
        else
            env.setText(text);
    }
    property var queued: null
    function run(cmd: list<string>): void {
        if (ctl.running) {
            queued = cmd;                 // keep the last request; run it when the current one ends
            return;
        }
        ctl.command = cmd;
        ctl.running = true;
    }
    function setMode(m: string): void {
        if (m !== "off")
            Settings.set("display.nightLight.lastMode", m);
        Settings.set("display.nightLight.mode", m);
    }
    function toggle(): void {
        setMode(on ? "off" : (cfg.lastMode ?? "auto"));
    }

    Connections {
        target: Settings
        function onDataChanged() {
            const c = Settings.data.display.nightLight;
            const key = [c.mode, c.temp, c.from, c.to, Settings.data.weather.lat, Settings.data.weather.lon].join();
            if (key !== root.lastKey) {
                root.lastKey = key;
                coalesce.restart();       // several settings changes in a row → one restart of wlsunset
            }
        }
    }
    property string lastKey: ""
    Timer {
        id: coalesce
        interval: 400
        onTriggered: root.apply()
    }
    // at startup: compare with what the service already runs; never restart it (gamma flicker) for nothing
    property string currentEnv: ""
    Component.onCompleted: {
        const c = Settings.data.display.nightLight;
        lastKey = [c.mode, c.temp, c.from, c.to, Settings.data.weather.lat, Settings.data.weather.lon].join();
    }

    FileView {
        id: env
        atomicWrites: true
        path: Paths.state + "/nightlight.env"
        printErrors: false
        onSaved: root.run(["systemctl", "--user", "restart", "ocarina-nightlight.service"])
    }
    function fail(why: string): void {
        if (error === why)
            return;
        error = why;
        Health.fail("Luz nocturna (wlsunset)", why);
    }
    Process {
        id: ctl
        onExited: code => {
            const verb = command[2] ?? "";
            if ((verb === "start" || verb === "restart") && code !== 0) {
                root.fail("ocarina-nightlight.service no arranca (journalctl --user -u ocarina-nightlight)");
            } else if (verb === "start" || verb === "restart" || verb === "stop") {
                root.error = "";
                Health.ok("Luz nocturna (wlsunset)");
            }
            if (root.queued) {
                const q = root.queued;
                root.queued = null;
                root.run(q);
            }
        }
    }
}
