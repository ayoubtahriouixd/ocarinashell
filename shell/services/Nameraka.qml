pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 滑 Nameraka — system-wide video frame generation (docs/01-ARQUITECTURA §19, fase 11 B). The helper
// (~/.local/libexec/ocarinashell/nameraka) does the work; the shell only:
// - reads ~/.local/state/ocarinashell/nameraka/selftest.json (written at login by ocarina-nameraka-selftest.service):
//   available + the reason, without starting anything;
// - opens the socket ($XDG_RUNTIME_DIR/ocarinashell/nameraka.sock, systemd starts the daemon on connect) ONLY while
//   Fluido is on: 0 processes and 0 cost with it off;
// - tells the daemon what niri does not: lock, screen off (pause/resume), the battery policy and Shinobi.
// Stats (1/s) are asked for only while Engawa or the OSD show them.
Singleton {
    id: root

    readonly property var cfg: Settings.data.nameraka
    // self-test
    property var selftest: ({})
    readonly property int code: selftest.code ?? -1
    readonly property bool tested: code >= 0
    readonly property bool available: code === 0
    // 10–12: the system cannot do it at all (no card); 13–14: show the card with the reason
    readonly property bool cardVisible: tested && (code === 0 || code >= 13)
    readonly property string unavailableReason: code === 13 ? "Falta lsfg-vk · Ajustes"
        : code === 14 ? "Falta Lossless Scaling (rama lsfg-vk) · Ajustes"
        : code > 0 ? (selftest.reason ?? "No disponible") : ""
    // policy
    readonly property bool blocked: Modes.shinobi
    readonly property bool batteryOff: Power.onBattery && cfg.battery === "off"
    readonly property bool eco: Power.onBattery && cfg.battery === "eco" && !Modes.oni

    // live state from the daemon
    property bool wanted: false            // the socket is open because Fluido is on
    property string state: "off"           // off | arming | starting | active | paused
    property var info: ({})                // the last state event
    property var stats: ({})               // the last stats event
    property string lastError: ""
    readonly property bool on: wanted && state !== "off"
    readonly property bool active: state === "active"
    readonly property bool arming: wanted && state === "arming"
    readonly property int m: info.m ?? 1
    readonly property real base: info.base ?? 0
    readonly property real hz: info.hz ?? 120
    readonly property real outFps: info.out ?? 0
    readonly property bool perfect: info.perfect ?? true
    readonly property bool limited: info.limited ?? false
    readonly property real audioDelay: info.audioDelayMs ?? 0
    // the panel's own resolution for «Calibrado · 2880×1800»
    readonly property string panelRes: {
        const o = Niri.outputs[info.output ?? ""] ?? Object.values(Niri.outputs).find(x => String(x.name ?? "").startsWith("eDP"));
        const m = o?.modes?.[o.current_mode ?? -1];
        return m ? m.width + "×" + m.height : "";
    }
    readonly property string app: info.app ?? ""
    readonly property int chosen: cfg.mode === "x2" ? 2 : cfg.mode === "x4" ? 4 : cfg.mode === "x6" ? 6 : 0
    readonly property int targetFps: cfg.fps > 0 ? cfg.fps : Math.round(hz)
    property int statsUsers: 0             // Engawa's page and the OSD count themselves in while visible
    readonly property bool statsWanted: statsUsers > 0

    // «×4 · 30 → 120 fps · Chrome», «×6 → ×4 · 120 Hz», «Pon el vídeo a pantalla completa»…
    readonly property string subtitle: {
        if (!tested)
            return "Comprobando…";
        if (!available)
            return unavailableReason;
        if (blocked)
            return "Bloqueado por 忍 Shinobi";
        if (batteryOff)
            return "Apagado con batería · Ajustes";
        if (!on)
            return lastError !== "" ? lastError : "Apagado · Lossless Scaling listo";
        if (state === "arming")
            return "Pon el vídeo a pantalla completa";
        if (state === "starting")
            return "Arrancando…";
        if (state === "paused")
            return "En pausa · vuelve solo";
        const b = base > 0 ? Math.round(base * 100) / 100 : 0;
        if (limited && chosen > 0)
            return "×" + chosen + " → ×" + m + " · " + Math.round(hz) + " Hz";
        return "×" + m + " · " + (b > 0 ? fmt(b) + " → " + Math.round(outFps) : "→ " + targetFps) + " fps"
            + (info.adjusted ? " · ajustado" : "") + (app !== "" ? " · " + appName(app) : "");
    }
    // ⚠ when base × m ≠ Hz: «24 × 4 = 96 ≠ 120 Hz: usa A medida»
    readonly property string warning: on && active && base > 0 && !perfect
        ? fmt(base) + " × " + m + " = " + Math.round(outFps) + " ≠ " + Math.round(hz) + " Hz: usa A medida" : ""

    function fmt(n: real): string {
        return String(Math.round(n * 100) / 100).replace(".", ",");
    }
    function appName(id: string): string {
        const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
        if (e?.name)
            return e.name;
        const known = { "google-chrome": "Chrome", "firefox": "Firefox", "mpv": "mpv", "chromium": "Chromium" };
        return known[id] ?? id;
    }

    // ── public (IPC `nameraka`, Engawa, Mod+Alt+F) ────────────────────────────────────────────
    function toggle(): void {
        if (wanted)
            off();
        else
            turnOn();
    }
    function turnOn(): void {
        lastError = "";
        if (!available || blocked || batteryOff) {
            Osd.show("info", 0, "Nameraka: " + subtitle, "slow_motion_video");
            autoStarted = false;
            return;
        }
        wanted = true;
        stopLater.stop();
        if (sock.connected)
            sendStart();                    // otherwise onConnectedChanged sends it
        else
            sock.connected = true;          // set, never bound: Socket writes `connected` itself on errors
    }
    function off(): void {
        if (sock.connected) {
            send({ cmd: "stop" });
            pendingStops++;                 // its «off» answer must not read as «switched off by itself»
        }
        stopped();
    }
    // every way out: no more «Automático» on this same window until it changes or leaves full screen
    function stopped(): void {
        wanted = false;
        state = "off";
        info = ({});
        autoStarted = false;
        suppressAuto();
        stopLater.restart();                // let the stop reach the daemon, then close the socket
    }
    // m: x2 | x4 | x6 | custom | next
    function setMode(m: string): void {
        const order = ["x2", "x4", "x6", "custom"];
        const next = m === "next" ? order[(order.indexOf(cfg.mode) + 1) % order.length] : m;
        if (order.indexOf(next) < 0)
            return;
        Settings.set("nameraka.mode", next);
        if (wanted)
            flashOsd();
    }
    function setFps(n: int): void {
        Settings.set("nameraka.fps", Math.max(0, n));
        Settings.set("nameraka.mode", "custom");
    }
    function setQuality(flow: real, perf: string): void {
        Settings.set("nameraka.flow", flow);
        Settings.set("nameraka.perf", perf);
    }
    function fullscreen(): void {
        send({ cmd: "fullscreen" });
    }
    function calibrate(): void {
        Quickshell.execDetached(["ocarina", "nameraka", "calibrate"]);
    }
    function status(): string {
        return JSON.stringify({ available: available, code: code, wanted: wanted, state: state, info: info, stats: stats });
    }

    // ── socket ────────────────────────────────────────────────────────────────────────────────
    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/ocarinashell/nameraka.sock"
    property int pendingStops: 0
    Timer {
        id: stopLater
        interval: 400
        onTriggered: if (!root.wanted) { sock.connected = false; root.pendingStops = 0; }
    }
    Socket {
        id: sock
        path: root.socketPath
        onConnectedChanged: {
            if (connected && root.wanted) {
                // what the daemon cannot know by itself goes first (a pause left from before must not stick)
                root.send({ cmd: root.lockPause ? "pause" : "resume", reason: "lock" });
                root.send({ cmd: root.screenPause ? "pause" : "resume", reason: "screen" });
                root.sendStart();
                root.send({ cmd: "stats", on: root.statsWanted });
            } else if (!connected && root.wanted) {
                // the daemon died or the socket is gone: Fluido is off (the daemon stops when its client goes)
                root.lastError = "El ayudante se cerró";
                root.stopped();
            }
        }
        onError: e => {
            root.lastError = "El ayudante no responde";
            root.stopped();
            Qt.callLater(() => sock.connected = false);
        }
        parser: SplitParser {
            onRead: line => root.handle(line)
        }
    }
    function send(obj: var): void {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify(obj) + "\n");
        sock.flush();
    }
    function params(): var {
        return {
            mode: cfg.mode, fps: cfg.fps, battery: eco ? "eco" : "normal", exclude: cfg.exclude ?? [], avSync: !!cfg.avSync,
            flow: cfg.flow > 0 ? cfg.flow : null, perf: cfg.perf === "on" ? true : cfg.perf === "off" ? false : null
        };
    }
    // any change (Engawa, Settei, battery) reaches a running daemon, from one place
    readonly property string paramsKey: JSON.stringify(params())
    onParamsKeyChanged: if (wanted && sock.connected) send(Object.assign({ cmd: "set" }, params()))
    // the window it is for: the one you were looking at, as the shell knows it (a daemon just started by the socket
    // may not know yet which window had the keyboard, e.g. while Engawa holds it)
    function sendStart(): void {
        const w = Niri.lastWindowId >= 0 && Niri.windows[Niri.lastWindowId] ? { window: Niri.lastWindowId } : {};
        send(Object.assign({ cmd: "start" }, w, params()));
    }
    function handle(line: string): void {
        let e = null;
        try { e = JSON.parse(line); } catch (x) { return; }
        if (e.ev === "state" || e.ev === "stats") {
            if ((e.state ?? "off") === "off" && pendingStops > 0) {
                pendingStops--;             // the answer to our own stop (maybe after a new start was sent)
                return;
            }
            const was = state;
            if (!wanted)
                return;                     // late events of a session we already left
            info = e;
            state = e.state ?? "off";
            if (e.ev === "stats")
                stats = e;
            if (state !== "off" && was === "off")
                flashOsd();                 // the first real answer: the OSD says what is happening
            if (state === "off" && was !== "off") {
                // the daemon switched off by itself (window closed, watchdog…): say why, close the socket
                lastError = e.reason && e.reason !== "apagado" ? "Apagado · " + e.reason : "";
                stopped();
            }
        } else if (e.ev === "shown") {
            // the presenter's surface is on screen now (first time or after a pause): our surfaces go above it
            presenting = true;
            remap();
            if (!osdShown)
                flashOsd();
        } else if (e.ev === "error") {
            lastError = e.msg ?? "Error";
            if (state === "off" || state === "starting") {
                send({ cmd: "stop" });      // never leave a half-started daemon behind
                stopped();
            }
            Osd.show("info", 0, "Nameraka: " + lastError, "warning");
        }
    }
    onStatsWantedChanged: send({ cmd: "stats", on: statsWanted })
    // the presenter has been on screen this session (Engawa and the toasts go to the overlay layer only then)
    property bool presenting: false
    onWantedChanged: if (!wanted) presenting = false

    // ── what niri does not know ───────────────────────────────────────────────────────────────
    readonly property bool lockPause: Lock.active
    readonly property bool screenPause: Idle.offIdle
    onLockPauseChanged: send({ cmd: lockPause ? "pause" : "resume", reason: "lock" })
    onScreenPauseChanged: send({ cmd: screenPause ? "pause" : "resume", reason: "screen" })
    onBlockedChanged: if (blocked && wanted) off()
    onBatteryOffChanged: if (batteryOff && wanted) off()
    // «Automático» (nameraka.auto, off by default): a window goes full screen while an MPRIS player of that same app is
    // playing → Fluido starts by itself (nothing is captured to guess whether there is video). Never on excluded apps,
    // gamescope or Steam games. One started this way stops (instead of arming) when the window leaves full screen; once
    // switched off (by hand or by itself) it does not come back on that window until another one is focused or it
    // leaves full screen.
    property bool autoStarted: false
    property int autoSuppressed: -1
    function suppressAuto(): void {
        autoSuppressed = Niri.focusedWindowId;
    }
    readonly property bool focusedFullscreen: {
        if (!cfg.auto || wanted)
            return false;                   // nothing to watch with «Automático» off or Fluido on
        const w = Niri.focusedWindow;
        const lay = Niri.focusedLayout ?? w?.layout;
        if (!w || !lay?.window_size)
            return false;
        const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
        const l = (ws ? Niri.outputs[ws.output] : null)?.logical;
        const pos = lay.tile_pos_in_workspace_view;
        const atOrigin = !pos || (Math.abs(pos[0]) < 1 && Math.abs(pos[1]) < 1);   // the daemon's own rule
        return !!l && atOrigin && Math.abs(lay.window_size[0] - l.width) <= 1 && Math.abs(lay.window_size[1] - l.height) <= 1;
    }
    onFocusedFullscreenChanged: if (!focusedFullscreen && !wanted) autoSuppressed = -1
    readonly property int focusedId: Niri.focusedWindowId
    onFocusedIdChanged: if (focusedId !== autoSuppressed) autoSuppressed = -1
    readonly property bool autoCandidate: {
        if (!focusedFullscreen || !available || blocked || batteryOff || !Media.playing)
            return false;
        const w = Niri.focusedWindow;
        if (w.id === autoSuppressed)
            return false;
        const id = String(w.app_id ?? "").toLowerCase();
        if (id === "" || id === "gamescope" || id.startsWith("steam_app_") || id === "org.quickshell"
                || (cfg.exclude ?? []).indexOf(w.app_id) >= 0)
            return false;
        const p = Media.player;
        const names = [p?.desktopEntry, p?.identity, p?.dbusName].map(x => String(x ?? "").toLowerCase());
        return names.some(n => n !== "" && (n.indexOf(id) >= 0 || id.indexOf(n.replace("org.mpris.mediaplayer2.", "").split(".")[0]) >= 0));
    }
    // deferred: turnOn() sets `wanted`, which focusedFullscreen (and so autoCandidate) reads — doing it inside this
    // change handler re-entered both bindings (binding loop warnings in the journal)
    onAutoCandidateChanged: if (autoCandidate) Qt.callLater(autoStart)
    function autoStart(): void {
        if (!autoCandidate || wanted)
            return;
        autoStarted = true;
        turnOn();
    }
    onStateChanged: if (state === "arming" && autoStarted) off()

    // «A medida» with a target that is another mode of the screen (60 on a 120 Hz panel): the panel goes to that
    // mode while the video plays (starting/active; never while arming) and back after. Never in Shinobi/Oni: they own
    // the refresh rate (Modes drops this first). The panel's NATIVE maximum decides, not the Hz we capped ourselves.
    property var refreshSaved: null
    readonly property real panelMaxHz: {
        const o = Displays.list.find(x => x.internal);
        const cur = o?.cur;
        const same = (o?.modes ?? []).filter(m => cur && m.w === cur.w && m.h === cur.h);
        return same.length > 0 ? Math.max(...same.map(m => m.r)) / 1000 : 120;
    }
    readonly property bool wantsLowerHz: wanted && (state === "starting" || state === "active" || state === "paused")
        && cfg.mode === "custom" && cfg.fps >= 30 && Modes.state === "normal" && !Modes.busy
        && Math.round(panelMaxHz) > cfg.fps && Math.round(panelMaxHz) % cfg.fps === 0
    readonly property string hzKey: wantsLowerHz ? String(cfg.fps) : ""
    onHzKeyChanged: applyHz()
    function applyHz(): void {
        if (refreshSaved !== null) {
            Displays.releaseRefresh(refreshSaved);
            refreshSaved = null;
        }
        if (hzKey !== "")
            refreshSaved = Displays.capRefresh(cfg.fps, false);
        hzStore.setText(JSON.stringify(refreshSaved ?? {}) + "\n");
    }
    // Modes calls this before Shinobi/Oni take the refresh rate (Displays has one owner at a time)
    function dropRefresh(): void {
        if (refreshSaved === null)
            return;
        Displays.releaseRefresh(refreshSaved);
        refreshSaved = null;
        hzStore.setText("{}\n");
    }
    // survives a shell restart: a cap left in outputs.kdl by a crashed shell is undone at start-up
    FileView {
        id: hzStore
        path: Paths.state + "/nameraka/refresh.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let s = null;
            try { s = JSON.parse(text()); } catch (e) {}
            if (s && Object.keys(s).length > 0 && !root.wanted) {
                Displays.releaseRefresh(s);
                setText("{}\n");
            }
        }
    }

    signal remap                           // the presenter just (re)appeared: shell surfaces map again above it

    // the OSD (1,2 s, its own overlay surface: the only thing of the shell visible over a full-screen video)
    property bool osdShown: false
    function flashOsd(): void {
        osdShown = true;
        osdHide.restart();
    }
    Timer {
        id: osdHide
        interval: 1200
        onTriggered: root.osdShown = false
    }

    FileView {
        id: test
        path: Paths.state + "/nameraka/selftest.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.selftest = JSON.parse(text());
            } catch (e) {
                root.selftest = { code: 99, reason: "selftest.json ilegible" };
            }
        }
        onLoadFailed: root.selftest = { code: 98, reason: "Sin comprobar (ocarina nameraka self-test)" }
    }
}
