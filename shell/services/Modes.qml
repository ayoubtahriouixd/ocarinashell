pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Power modes orchestrator: one state "normal" | "shinobi" | "oni" (docs/01-ARQUITECTURA §10). The two modes exclude
// each other: asking for one while the other is on first leaves it (its snapshot restored) and only then enters.
// Each mode: off → entering → on → leaving → off. Entering first reads what it is about to change (helper status,
// keyboard light…), writes that snapshot to ~/.local/state/ocarinashell/<mode>-prev.json and only then applies, in
// order and each step idempotent. Only what the mode itself changed is written down and put back on leaving; values
// Ayoub changes by hand meanwhile are respected. A snapshot survives a crash, a reload or a reboot: at start-up an
// active one resumes the mode and re-applies what the kernel forgot (never re-snapshotted).
// A transition never blocks: requests that arrive during one are queued (the last wins) and a 15 s watchdog ends a
// transition whose steps hang.
//
// 忍 Shinobi: shell (Motion held, no blur/transparency, theme 「shinobi」, black wallpaper, minimal island, no peak
// meter/weather/seconds, silent) → niri (shinobi.kdl) → screen (60 Hz through Displays, brightness ceilings, keyboard
// light off) → energy (PPD power-saver, which also drops the turbo on amd-pstate; the helper only if it is still on;
// GPU low if chosen) → radios (Bluetooth off unless audio is connected, Wi-Fi power save) → apps (Ghostty/Neovim
// effects through TermFx, configured user units stopped). Triggers: Mod+Alt+S / Engawa / `ocarina shinobi`, battery ≤
// power.autoShinobiAt (asks or enters), leaving when the charger is plugged in (power.exitShinobiOnAC).
//
// 鬼 Oni (phase 11, D-060): shell (Motion held, no blur, polls paused, No molestar, the 鬼 island with temperatures
// and watts, «覚醒» once) → niri (oni.kdl: VRR for game windows) → screen (fastest mode + on-demand VRR through
// Displays) → energy (PPD performance = Lenovo's performance platform profile and its higher power limits, turbo on,
// scx_lavd in gaming mode, GPU level if chosen, turbo off with «prioridad a la GPU») → radios (Wi-Fi without power
// save) → fan at full speed (optional, on AC) → apps (configured user units stopped). Triggers: Mod+Alt+O / Engawa /
// `ocarina oni`, GameMode (`ocarina oni auto-on|auto-off` from ~/.config/gamemode.ini: back exactly as it was when
// the last game closes). Guards while on: Tctl ≥ 97 °C for 10 s or battery below oni.exitBatteryAt → leave and warn.
Singleton {
    id: root

    property string state: "normal"
    property string phase: "off"            // off | entering | on | leaving
    property string target: ""              // the mode being entered, or "normal" while leaving
    readonly property bool shinobi: state === "shinobi"
    readonly property bool oni: state === "oni"
    // from one mode to the other the state passes through "normal" while the first one is undone: the shell must not
    // wake up for that moment (blur regions, seconds, weather) only to go quiet again
    readonly property bool chaining: phase === "leaving" && want !== "" && want !== "normal"
    readonly property bool quiet: state !== "normal" || chaining     // polls and decoration that every mode pauses
    readonly property bool busy: phase === "entering" || phase === "leaving"
    readonly property var cfg: Settings.data.shinobi
    readonly property var oniCfg: Settings.data.oni
    property var prev: null                 // the snapshot of the active mode (reassigned on every change)
    readonly property var refreshSaved: prev?.refresh ?? ({})
    property int lastMs: 0                  // duration of the last transition (until every step finished)
    property string lastReason: ""
    property string want: ""                // a request that arrived during a transition: "normal" | "shinobi" | "oni"
    property string wantReason: ""
    property bool wantAuto: false
    property int epoch: 0                   // one per transition: late callbacks of an older one are ignored
    readonly property string snapshotPath: Paths.state + "/shinobi-prev.json"
    readonly property string oniSnapshotPath: Paths.state + "/oni-prev.json"

    // config singletons never import services: the mode writes into them (declaratively, so nothing can miss it)
    Binding { target: Motion; property: "held"; value: root.quiet }
    Binding { target: Theme; property: "lean"; value: root.quiet }

    signal awakened                          // 鬼 «覚醒»: the island stamps its seal, the edges glow once
    property bool kakusei: false             // the edge glow window exists only during those 600 ms
    // not over a game GameMode just opened: a full-screen overlay would break its direct scan-out for that moment
    onAwakened: if (Motion.allowed && !entryAuto) { kakusei = true; kakuseiEnd.restart(); }
    Timer {
        id: kakuseiEnd
        interval: Math.round(Motion.page * Motion.scale) + 150
        onTriggered: root.kakusei = false
    }

    property string logMode: "shinobi"      // the mode the current (or last) transition is about
    function log(msg: string): void {
        console.info(logMode + ": " + msg);
    }

    // ── public ──────────────────────────────────────────────────────────────────────────────────
    // request(): the one way in or out. While busy the request is queued; from one mode to the other = leave first.
    function request(m: string, reason: string): string {
        if (busy || !loaded) {               // a transition running, or the snapshots not read yet (start-up)
            want = m;
            wantReason = reason;
            return "en cola: " + m;
        }
        if (m === "oni" && oniLowBatteryAt())
            return "batería baja";
        if (state === m)
            return m === "normal" ? "off" : "on";
        if (state !== "normal") {
            if (m !== "normal") {
                want = m;                     // restore first, apply after (finish() picks it up)
                wantReason = reason;
            }
            leave(reason);
            return "leaving";
        }
        if (m === "shinobi")
            enter(reason);
        else if (m === "oni")
            enterOni(reason);
        return "entering";
    }
    function toggleMode(m: string, reason: string): string {
        if (busy) {
            const dest = want || target;      // where the running chain ends up
            want = dest === m ? "normal" : m;
            wantReason = reason;
            return "en cola: " + want;
        }
        return request(state === m ? "normal" : m, reason);
    }
    // 忍 (IPC `shinobi`, Settei, the battery trigger)
    function toggle(reason: string): string {
        return toggleMode("shinobi", reason);
    }
    function on(reason: string): string {
        return request("shinobi", reason || "manual");
    }
    function off(reason: string): string {
        if (want === "shinobi") {
            want = "";                        // asked meanwhile and never entered: forget it
            return "cancelado";
        }
        if (state !== "shinobi" && target !== "shinobi")
            return "off";
        return request("normal", reason || "manual");
    }
    // 鬼 (IPC `oni`, Settei, GameMode)
    function oniToggle(reason: string): string {
        wantAuto = false;
        return toggleMode("oni", reason);
    }
    function oniOn(reason: string): string {
        wantAuto = false;
        return request("oni", reason || "manual");
    }
    function oniOff(reason: string): string {
        if (want === "oni") {
            want = "";
            wantAuto = false;
            return "cancelado";
        }
        if (state !== "oni" && target !== "oni")
            return "off";
        return request("normal", reason || "manual");
    }
    function status(): string {
        return JSON.stringify({ state: state, phase: phase, target: target, ms: lastMs, reason: lastReason, want: want,
                                held: Motion.held, lean: Theme.lean, capInternal: Brightness.capInternal,
                                capExternal: Brightness.capExternal, refreshCap: Displays.refreshCap,
                                refreshMax: Displays.refreshMax, games: games,
                                sensors: oni ? { tctl: Sensors.cpuTemp, gpu: Sensors.gpuTemp, watts: Sensors.watts } : null,
                                snapshot: prev });
    }

    // ── steps that run as processes (counted: the transition ends when the last one does) ─────
    property int pending: 0
    property double t0: 0
    function job(cmd: var, done: var): void {
        pending++;
        const p = jobC.createObject(root, { command: cmd, done: done ?? null, ep: epoch });
        p.running = true;
    }
    function stepDone(): void {
        pending = Math.max(0, pending - 1);
        maybeFinish();
    }
    function maybeFinish(): void {
        if (!busy || pending > 0 || PowerCtl.busy || ThemeCtl.busy)
            return;
        finish();
    }
    function finish(): void {
        watchdog.stop();
        lastMs = Date.now() - t0;
        if (phase === "entering" && state !== target) {
            // the watchdog ended an entry whose probe never came back: nothing was applied, so the mode is not on
            phase = "off";
            Health.fail(logMode === "oni" ? "Oni" : "Shinobi", "no se pudo leer el estado del equipo: el modo no se activó");
            target = "";
            want = "";
            return;
        }
        if (phase === "entering") {
            phase = "on";
            log("on in " + lastMs + " ms" + (estimate !== "" && shinobi ? " · est. " + estimate : ""));
            if (oni)
                oniToast();
            else
                toast();
        } else {
            phase = "off";
            log("off in " + lastMs + " ms");
        }
        target = "";
        // what was asked meanwhile (the key twice, the charger plugged in during the entry, Oni asked in Shinobi…)
        const w = want, r = wantReason;
        want = "";
        wantReason = "";
        if (w !== "" && w !== state)
            Qt.callLater(() => root.request(w, r || "en cola"));
    }
    // a hung step (a stop that waits for TimeoutStopSec, pkexec waiting for an agent…) never blocks the mode
    Timer {
        id: watchdog
        interval: 15000
        onTriggered: {
            if (!root.busy)
                return;
            Health.fail(root.logMode === "oni" ? "Oni" : "Shinobi", "la transición (" + root.phase
                        + ") no terminó en 15 s: pasos pendientes " + root.pending
                        + (PowerCtl.busy ? ", ayudante" : "") + (ThemeCtl.busy ? ", tema" : ""));
            root.pending = 0;
            root.finish();
        }
    }
    // the helper queue and the theme engine end on their own: look again when they do
    Connections {
        target: PowerCtl
        function onBusyChanged() { if (!PowerCtl.busy) Qt.callLater(root.maybeFinish); }
    }
    Connections {
        target: ThemeCtl
        function onBusyChanged() {
            if (ThemeCtl.busy)
                return;
            if (Motion.modeFade)
                fadeEnd.restart();          // the colours fade from now on: keep the fade allowed until they end
            Qt.callLater(root.maybeFinish);
        }
    }
    Component {
        id: jobC
        Process {
            id: p
            property var done: null
            property int ep: 0
            stdout: StdioCollector { id: pOut }
            onExited: code => {
                // a step of an older transition (the watchdog gave up on it) neither counts nor applies anything now
                if (p.ep === root.epoch) {
                    if (p.done)
                        p.done(code, pOut.text);
                    root.stepDone();
                }
                p.destroy();
            }
        }
    }
    function begin(m: string, reason: string): void {
        t0 = Date.now();
        phase = m === "normal" ? "leaving" : "entering";
        target = m;
        logMode = m === "normal" ? state : m;
        lastReason = reason;
        epoch++;
        pending = 0;                          // steps still running from before belong to an older epoch
        watchdog.restart();
        Motion.modeFade = true;
        fadeEnd.restart();
    }
    function probeLine(text: string, tag: string): var {
        const l = text.split("\n").find(x => x.startsWith(tag + " "));
        try {
            return JSON.parse(l ? l.slice(2) : "{}");
        } catch (e) {
            return {};
        }
    }
    function leave(reason: string): void {
        if (state === "oni")
            leaveOni(reason);
        else
            leaveShinobi(reason);
    }

    // ══ 忍 Shinobi ══════════════════════════════════════════════════════════════════════════════
    property string estimate: ""
    property real watts: 0
    function enter(reason: string): void {
        begin("shinobi", reason);
        watts = Power.meanWatts();
        const h = Power.hoursAt(watts);
        estimate = h > 0 ? Math.floor(h) + " h " + Math.round((h % 1) * 60) + " min" : "";
        log("entering (" + reason + (Power.hasBattery ? ", battery " + Math.round(Power.percent * 100) + " %" : "")
            + (Power.onBattery ? ", unplugged" : ", on AC") + ")");
        // read what is about to change: S = helper status, K = keyboard light, B = panel backlight (it may have been
        // changed outside the shell: brightnessctl, a script)
        job(["sh", "-c", 'printf "S "; { [ -x "$0" ] && "$0" status; } || echo "{}"; printf "K "; '
             + 'busctl --timeout=2 --json=short call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight '
             + 'org.freedesktop.UPower.KbdBacklight GetBrightness 2>/dev/null || echo "{}"; '
             + 'printf "B %s\n" "$(brightnessctl -m -c backlight 2>/dev/null | cut -d, -f4 | tr -dc 0-9)"', PowerCtl.helper],
            (code, text) => root.applyAll(text));
    }
    function applyAll(probeText: string): void {
        if (phase !== "entering" || target !== "shinobi")
            return;                           // the watchdog ended it already
        const st = probeLine(probeText, "S");
        const kbd = probeLine(probeText, "K").data?.[0] ?? -1;
        const backlight = Number(probeLine(probeText, "B")) || -1;
        const panel = Brightness.entries.find(e => e.kind === "internal");
        if (panel && backlight > 0 && Brightness.dimSaved === null && panel.pct !== backlight)
            Brightness.update(panel.name, { pct: backlight });
        const my = epoch;

        // only what Shinobi itself changes is written down: kbd -1 / boostOff false / gpu "" = untouched
        const snap = {
            mode: "shinobi", active: true, at: new Date().toISOString(), reason: lastReason, onBattery: Power.onBattery,
            profile: Power.profile, kbd: cfg.kbdLightOff && kbd > 0 ? kbd : -1, brightness: {}, refresh: {},
            boostOff: false, gpu: cfg.gpuLow && st.gpu === "auto" ? "auto" : "",
            wifiOff: [], bt: false, units: []
        };
        // brightness: the real value (the one under the idle dimming) of each screen the ceiling will cut
        const capOf = e => {
            const c = e.kind === "internal" ? Number(cfg.brightnessCap) || 0
                : Number(cfg.brightnessCapExternal) < 100 ? Number(cfg.brightnessCapExternal) : 0;
            return c > 0 ? c : 100;
        };
        for (const e of Brightness.entries) {
            const real = Brightness.realPct(e.name);
            if (real > capOf(e))
                snap.brightness[e.name] = { was: real, cap: capOf(e) };
        }
        if (cfg.wifiPowersave)
            for (const i in (st.wifiPs ?? {}))
                if (st.wifiPs[i] === "off")
                    snap.wifiOff.push(i);
        snap.bt = cfg.bluetoothOff && Bt.enabled && !(cfg.bluetoothKeepAudio && audioConnected());
        // screen: Displays writes outputs.kdl now and reports the modes it replaced
        // VRR at 120 Hz by default: −1,0 W (the panel idles at 30 Hz) against −0,5 W for 60 Hz, and no modeset, so the
        // OLED does not blink black on entering (docs/ENERGIA.md scenarios B/C, Ayoub fase 15); 60 Hz stays an option
        Nameraka.dropRefresh();             // Displays has one owner: Nameraka's «A medida» cap gives way first
        if (cfg.refresh60 || cfg.vrr)
            snap.refresh = Displays.capRefresh(cfg.refresh60 ? 60 : 120, cfg.vrr ?? false);
        commit(snap);
        log("snapshot → " + snapshotPath);

        // shell: the switch everything else binds to
        state = "shinobi";
        fadeEnd.restart();
        ThemeCtl.hold("shinobi");
        // niri
        writeNiri("shinobi", true);
        // screen
        Brightness.clampAll();
        if (snap.kbd > 0) {
            KbdLight.level = snap.kbd;        // what is really lit (Fn+Space does not tell KbdLight)
            KbdLight.set(0);
        }
        // energy: PPD's power-saver already drops the turbo on amd-pstate (policy*/boost); the helper only steps
        // in when it is still on afterwards (another driver, an older PPD)
        if (Power.profile !== "power-saver")
            Power.setProfile("power-saver", true);
        if (cfg.boostOff && st.boost === true)
            job(["sh", "-c", 'sleep 0.25; cat /sys/devices/system/cpu/cpufreq/policy0/boost 2>/dev/null || cat /sys/devices/system/cpu/cpufreq/boost'],
                (code, text) => {
                    if (text.trim() !== "1" || root.epoch !== my || !root.shinobi)
                        return;
                    PowerCtl.run(["boost", "off"], null);
                    root.commit(Object.assign({}, root.prev, { boostOff: true }));
                });
        if (snap.gpu !== "")
            PowerCtl.run(["gpu", "low"], null);
        // radios
        for (const i of snap.wifiOff)
            PowerCtl.run(["wifi-ps", "on", i], null);
        if (snap.bt)
            Bt.backend?.setEnabled(false, false);   // temporary: not saved across a reboot
        // apps: TermFx follows Modes.shinobi by itself; configured user units: write down which run, then stop them
        pauseUnits(cfg.pauseServices ?? [], my, "shinobi");
        log("niri: include shinobi.kdl" + (Object.keys(snap.refresh).length > 0 ? ((cfg.refresh60 ? " · 120→60 Hz" : "") + (cfg.vrr ? " · VRR" : "")) : "")
            + " · ppd power-saver");
    }
    function leaveShinobi(reason: string): void {
        begin("normal", reason);
        log("leaving (" + reason + ")");
        const s = prev ?? {};
        state = "normal";
        Notifs.dismissApp("Shinobi");
        ThemeCtl.release();
        writeNiri("shinobi", false);
        Displays.releaseRefresh(s.refresh ?? {});
        // brightness: back to the old value only where it still sits at the ceiling (nobody moved it meanwhile)
        for (const name in (s.brightness ?? {})) {
            const b = s.brightness[name];
            if (b && typeof b === "object" && Brightness.realPct(name) === b.cap)
                Brightness.restoreTo(name, b.was);
        }
        if (s.kbd > 0)
            KbdLight.set(s.kbd);
        // turbo back before the profile: PPD writes policy*/boost itself when the profile changes
        const profileBack = () => { if (s.profile && Power.profile === "power-saver" && s.profile !== "power-saver") Power.setProfile(s.profile, true); };
        if (s.boostOff)
            PowerCtl.run(["boost", "on"], ok => profileBack());
        else
            profileBack();
        if (s.gpu)
            PowerCtl.run(["gpu", s.gpu], null);
        for (const i of (s.wifiOff ?? []))
            PowerCtl.run(["wifi-ps", "off", i], null);
        if (s.bt)
            Bt.backend?.setEnabled(true, false);
        resumeUnits(s.units ?? []);
        prev = null;
        save("shinobi", { mode: "shinobi", active: false, at: new Date().toISOString(), reason: reason });
        Qt.callLater(maybeFinish);
    }

    // ══ 鬼 Oni ══════════════════════════════════════════════════════════════════════════════════
    property bool entryAuto: false          // the entry running now came from GameMode
    property bool games: false              // GameMode says a game is running (between auto-on and auto-off)
    readonly property string gpuWanted: oniCfg.gpuLevel === "high" ? "high" : ""
    function enterOni(reason: string): void {
        entryAuto = wantAuto;
        wantAuto = false;
        begin("oni", reason);
        log("entering (" + reason + (Power.onBattery ? ", unplugged" : ", on AC") + ")");
        // S = helper status, P = the profile PPD really has (after leaving Shinobi the property may still lag)
        job(["sh", "-c", '{ [ -x "$0" ] && printf "S " && "$0" status; } || echo "S {}"; '
             + 'printf "P \"%s\"\n" "$(powerprofilesctl get 2>/dev/null)"', PowerCtl.helper],
            (code, text) => root.applyOni(text));
    }
    function applyOni(probeText: string): void {
        if (phase !== "entering" || target !== "oni")
            return;
        const st = probeLine(probeText, "S");
        const ppd = String(probeLine(probeText, "P") || "");
        const c = oniCfg;
        const my = epoch;
        // only what Oni itself changes: boostOn/boostOff false, gpu "", scx false, fan "" = untouched
        const snap = {
            mode: "oni", active: true, at: new Date().toISOString(), reason: lastReason, auto: entryAuto,
            onBattery: Power.onBattery, profile: /^(power-saver|balanced|performance)$/.test(ppd) ? ppd : Power.profile,
            boostOn: false, boostOff: false,
            gpu: gpuWanted !== "" && st.gpu && st.gpu !== gpuWanted ? st.gpu : "",
            scx: !!c.scx && st.scxAvailable === true && !st.scx,
            fan: c.fanMax && st.fan?.control === true && !Power.onBattery && st.fan.level !== "full-speed"
                 ? (st.fan.level === "disengaged" ? "auto" : st.fan.level || "auto") : "",
            refresh: {}, wifiOn: [], units: []
        };
        if (c.wifiNoPs)
            for (const i in (st.wifiPs ?? {}))
                if (st.wifiPs[i] === "on")
                    snap.wifiOn.push(i);
        Nameraka.dropRefresh();
        snap.refresh = Displays.boostRefresh(!!c.vrrGames);
        commit(snap);
        log("snapshot → " + oniSnapshotPath);

        // shell: Motion/blur/polls follow `state`; No molestar binds to it in Notifs; «覚醒» once
        state = "oni";
        fadeEnd.restart();
        awakened();
        // niri: VRR for game windows (only while the mode is on)
        writeNiri("oni", true);
        // energy: PPD performance (Lenovo's performance platform profile) and EPP performance; scx_lavd first so PPD's
        // scx_loader integration finds it running when the profile changes (it switches it to gaming as well)
        if (snap.scx)
            PowerCtl.run(["scx", "lavd"], null);
        if (Power.profile !== "performance")
            Power.setProfile("performance", true);
        if (snap.gpu !== "")
            PowerCtl.run(["gpu", gpuWanted], null);
        // turbo: on (PPD performance already turns it on), or off with «prioridad a la GPU»; looked at after PPD has
        // written policy*/boost, and only when there is something to do (it is on and stays on most of the time)
        if (c.gpuFirst || st.boost === false)
            job(["sh", "-c", 'sleep 0.3; cat /sys/devices/system/cpu/cpufreq/policy0/boost 2>/dev/null || cat /sys/devices/system/cpu/cpufreq/boost'],
                (code, text) => {
                    if (root.epoch !== my || !root.oni)
                        return;
                    const b = text.trim();
                    if (c.gpuFirst && b === "1") {
                        PowerCtl.run(["boost", "off"], null);
                        root.commit(Object.assign({}, root.prev, { boostOff: true }));
                    } else if (!c.gpuFirst && b === "0") {
                        PowerCtl.run(["boost", "on"], null);
                        root.commit(Object.assign({}, root.prev, { boostOn: true }));
                    }
                });
        // radios and fan
        for (const i of snap.wifiOn)
            PowerCtl.run(["wifi-ps", "off", i], null);
        if (snap.fan !== "")
            PowerCtl.run(["fan", "full"], null);
        // apps: configured user units (image clipboard history, night light if chosen)
        const units = (c.pauseServices ?? []).concat(c.nightLightPause ? ["ocarina-nightlight.service"] : []);
        pauseUnits(units, my, "oni");
        log("niri: include oni.kdl · ppd performance" + (snap.scx ? " · scx_lavd" : "")
            + (snap.gpu !== "" ? " · gpu " + gpuWanted : "") + (snap.fan !== "" ? " · fan full" : ""));
    }
    function leaveOni(reason: string): void {
        begin("normal", reason);
        log("leaving (" + reason + ")");
        const s = prev ?? {};
        state = "normal";
        Notifs.dismissApp("Oni · ");
        writeNiri("oni", false);
        Displays.releaseRefresh(s.refresh ?? {});
        // scheduler off before the profile changes (PPD would only switch its mode again)
        if (s.scx)
            PowerCtl.run(["scx", "stop"], null);
        if (s.profile && Power.profile === "performance" && s.profile !== "performance")
            Power.setProfile(s.profile, true);
        // after the profile: PPD writes policy*/boost itself when it changes, so look once it has, and only correct
        // what is not back to how it was
        if (s.boostOn || s.boostOff)
            job(["sh", "-c", 'sleep 0.3; cat /sys/devices/system/cpu/cpufreq/policy0/boost 2>/dev/null || cat /sys/devices/system/cpu/cpufreq/boost'],
                (code, text) => {
                    const b = text.trim();
                    if (s.boostOn && b === "1")
                        PowerCtl.run(["boost", "off"], null);
                    else if (s.boostOff && b === "0")
                        PowerCtl.run(["boost", "on"], null);
                });
        if (s.gpu)
            PowerCtl.run(["gpu", s.gpu], null);
        for (const i of (s.wifiOn ?? []))
            PowerCtl.run(["wifi-ps", "on", i], null);
        if (s.fan)
            PowerCtl.run(["fan", "auto"], null);
        resumeUnits(s.units ?? []);
        hot = 0;
        prev = null;
        save("oni", { mode: "oni", active: false, at: new Date().toISOString(), reason: reason });
        Qt.callLater(maybeFinish);
    }

    // GameMode: ~/.config/gamemode.ini runs `ocarina oni auto-on` when the first game starts and `auto-off` when the
    // last one ends. auto-off only undoes an Oni that auto-on started (a manual Oni stays).
    function autoOn(): string {
        games = true;
        if (!oniCfg.auto)
            return "automático desactivado";
        if (state === "oni" || target === "oni")
            return "on";
        if (state === "shinobi" || target === "shinobi") {
            ask("shinobi", "Juego abierto en Shinobi", "¿Pasar a 鬼 Oni? Sale de Shinobi y pone todo el equipo para el juego.");
            return "en Shinobi: pregunto";
        }
        if (Power.onBattery && oniCfg.batteryAuto !== "allow") {
            if (oniCfg.batteryAuto === "never")
                return "con batería: no";
            ask("battery", "Juego abierto con batería", "¿Activar 鬼 Oni? Gasta mucha más batería; sale solo al "
                + oniCfg.exitBatteryAt + " %.");
            return "con batería: pregunto";
        }
        wantAuto = true;
        return request("oni", "auto");
    }
    function autoOff(): string {
        games = false;
        if (asker.running && asker.kind !== "shinobi-battery")
            asker.running = false;            // the question no longer applies
        if (want === "oni" && wantAuto) {
            want = "";                        // asked (Shinobi → Oni, «Activar») and the game is already closed
            wantAuto = false;
            return "cancelado";
        }
        if (target === "oni" && busy && entryAuto) {
            want = "normal";
            wantReason = "juego cerrado";
            return "en cola: normal";
        }
        if (oni && prev?.auto === true)
            return request("normal", "juego cerrado");
        return oni ? "manual: sigue" : "off";
    }

    // guards while Oni is on: temperature (Sensors, every 2 s), battery, the charger pulled with the fan at full speed
    property int hot: 0
    Connections {
        target: Sensors
        enabled: root.oni && root.phase === "on"
        function onSampled() {
            root.hot = Sensors.cpuTemp >= 97 ? root.hot + 1 : 0;
            if (root.hot >= 5) {                 // 5 samples × 2 s = 10 s sustained
                root.hot = 0;
                root.warn("Temperatura de la CPU a " + Math.round(Sensors.cpuTemp) + " °C",
                          "鬼 Oni se ha apagado para proteger el equipo. Deja que se enfríe antes de volver.");
                root.request("normal", "temperatura");
            }
        }
    }
    function oniLowBatteryAt(): bool {
        return Power.hasBattery && Power.onBattery && Power.percent * 100 < (Number(oniCfg.exitBatteryAt) || 0);
    }
    readonly property bool oniLowBattery: oni && phase === "on" && Power.hasBattery && Power.onBattery
                                          && Power.percent * 100 < (Number(oniCfg.exitBatteryAt) || 0)
    onOniLowBatteryChanged: {
        if (!oniLowBattery)
            return;
        warn("Batería al " + Math.round(Power.percent * 100) + " %", "鬼 Oni se ha apagado para no quedarte sin batería.");
        request("normal", "batería");
    }
    function warn(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Oni", "-u", "critical", "-h", "string:x-ocarina-kanji:鬼",
                                 title, body]);
    }

    // ── shared pieces ───────────────────────────────────────────────────────────────────────────
    function commit(snap: var): void {
        prev = snap;
        save(snap.mode ?? state, snap);
    }
    function save(m: string, snap: var): void {
        (m === "oni" ? oniStore : store).setText(JSON.stringify(snap, null, 1) + "\n");
    }
    function pauseUnits(list: var, my: int, m: string): void {
        const units = list.filter(u => /^[A-Za-z0-9@._-]+\.(service|timer)$/.test(u));
        if (units.length === 0)
            return;
        job(["sh", "-c", 'for u; do systemctl --user -q is-active "$u" && echo "$u"; done; true', "sh"].concat(units),
            (code, text) => {
                const running = text.split("\n").filter(x => x !== "");
                if (running.length === 0 || root.epoch !== my || root.state !== m)
                    return;
                root.commit(Object.assign({}, root.prev, { units: running }));
                root.job(["systemctl", "--user", "stop", "--no-block"].concat(running), null);
            });
    }
    function resumeUnits(units: var): void {
        if (units.length > 0)
            job(["systemctl", "--user", "start", "--no-block"].concat(units), null);
    }
    onCfgChanged: if (shinobi) Brightness.clampAll()
    function audioConnected(): bool {
        for (const d of (Bt.backend?.devices ?? []))
            if (d.connected && String(d.icon ?? "").startsWith("audio"))
                return true;
        return false;
    }
    // niri includes. shinobi.kdl: animations off, no shadows, a dim focus ring (config/niri/reference/shinobi.kdl).
    // oni.kdl: on-demand VRR for game windows (gamescope, Steam/Proton games through xwayland-satellite).
    readonly property string niriText: [
        "// GENERATED — owner: Modes (忍 Shinobi). Present only while the mode is on.",
        "animations {", "    off", "}",
        "layout {", "    shadow {", "        off", "    }", "    focus-ring {",
        "        active-color \"#5c0010\"", "        active-gradient from=\"#5c0010\" to=\"#5c0010\"",
        "        inactive-color \"#000000\"", "    }", "}",
        "overview {", "    workspace-shadow {", "        off", "    }", "}",
        "layer-rule {", "    match namespace=\"^ocarina-\"", "    shadow {", "        off", "    }", "}", ""].join("\n")
    readonly property string oniNiriText: [
        "// GENERATED — owner: Modes (鬼 Oni). Present only while the mode is on.",
        "window-rule {", "    match app-id=\"^gamescope$\"", "    match app-id=\"^steam_app_\"",
        "    match app-id=\"^steam_proton$\"", "    variable-refresh-rate true", "}", ""].join("\n")
    function writeNiri(m: string, on: bool): void {
        const owner = m === "oni" ? "鬼 Oni" : "忍 Shinobi";
        const text = !on ? "// GENERATED — owner: Modes (" + owner + "). Empty: the mode is off.\n"
            : m === "oni" ? (oniCfg.vrrGames ? oniNiriText : "// GENERATED — owner: Modes (鬼 Oni). VRR en juegos: no.\n")
            : niriText;
        job(["sh", "-c", 'printf "%s" "$1" | "$0" apply "$2"', Paths.bin + "/ocarina-niri-gen", text, m], (code, out) => {
            if (code !== 0)
                Health.fail(m === "oni" ? "Oni (niri)" : "Shinobi (niri)", m + ".kdl rechazado");
        });
    }
    // the fade to black (wallpaper veil, theme colours) and the seal stamps are the only motion while changing modes;
    // restarted when the state flips and when the theme engine is done, so the fade is never cut halfway
    Timer {
        id: fadeEnd
        interval: Math.round(Motion.emphasized * Motion.scale) + 150
        onTriggered: Motion.modeFade = false
    }

    // ── the toasts (mockups 06 and 08) ──────────────────────────────────────────────────────────
    property var toastQueued: null
    function toast(): void {
        const parts = [];
        if (Power.onBattery && estimate !== "")
            parts.push("Autonomía estimada <b>" + estimate + "</b> · " + watts.toFixed(1).replace(".", ",") + " W");
        else if (!Power.onBattery)
            parts.push("Con cargador");
        if (Object.keys(prev?.refresh ?? {}).length > 0)
            parts.push("60 Hz");
        parts.push("sin animaciones ni desenfoque");
        if (prev?.bt)
            parts.push("Bluetooth apagado");
        if ((prev?.units ?? []).length > 0)
            parts.push((prev.units.length === 1 ? "1 servicio" : prev.units.length + " servicios") + " en pausa");
        showToast(["notify-send", "-a", "Shinobi", "-h", "string:x-ocarina-kanji:忍", "-t", "8000",
                   "-A", "exit=Salir de Shinobi", "-A", "settings=Ajustes",
                   "Modo ahorro extremo activado", parts.join(" · ")]);
    }
    function oniToast(): void {
        const s = prev ?? {};
        const panel = Displays.list.find(o => o.internal);
        const m = panel?.cur ? Displays.capped(panel, panel.cur) : null;   // what Displays just wrote, not what niri said
        const hz = m ? Math.round(m.r / 1000) : 0;
        const parts = [];
        if (hz > 0)
            parts.push(hz + " Hz" + (oniCfg.vrrGames && panel?.vrrSupported ? " + VRR" : ""));
        parts.push(s.scx ? "scx gaming" : "perfil rendimiento");
        if (s.boostOff)
            parts.push("prioridad a la GPU");
        if (s.gpu)
            parts.push("GPU alta");
        if (s.fan)
            parts.push("ventilador al máximo");
        if (oniCfg.dnd)
            parts.push("No molestar");
        if ((s.units ?? []).length > 0)
            parts.push((s.units.length === 1 ? "1 servicio" : s.units.length + " servicios") + " en pausa");
        if (Power.onBattery)
            parts.push("con batería: sale solo al " + oniCfg.exitBatteryAt + " %");
        showToast(["notify-send", "-a", "Oni · 覚醒", "-h", "string:x-ocarina-kanji:鬼", "-h", "string:x-ocarina-mode:oni",
                   "-t", "6000", "-A", "exit=Salir de Oni", "-A", "settings=Ajustes",
                   s.auto ? "Modo Oni activado — todo el equipo para el juego" : "Modo Oni activado — máxima potencia",
                   parts.join(" · ")]);
    }
    function showToast(cmd: var): void {
        if (toaster.running) {
            toastQueued = cmd;                // a second entry within the timeout: shown when the first one is answered
            return;
        }
        toaster.command = cmd;
        toaster.running = true;
    }
    Process {
        id: toaster
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.trim();
                const oniToast = String(toaster.command?.[2] ?? "").startsWith("Oni");
                if (a === "exit")
                    oniToast ? root.oniOff("toast") : root.off("toast");
                else if (a === "settings")
                    Settei.show(oniToast ? "oni" : "shinobi");
            }
        }
        onExited: {
            if (root.toastQueued && root.state !== "normal") {
                toaster.command = root.toastQueued;
                toaster.running = true;
            }
            root.toastQueued = null;
        }
    }

    // ── questions (battery thresholds, GameMode unplugged or in Shinobi) ────────────────────────
    function ask(kind: string, title: string, body: string): bool {
        if (asker.running)
            return false;                     // one question at a time
        asker.kind = kind;
        asker.command = ["notify-send", "-a", kind === "shinobi-battery" ? "Shinobi" : "Oni", "-u", "critical",
                         "-h", "string:x-ocarina-kanji:" + (kind === "shinobi-battery" ? "忍" : "鬼"),
                         "-A", "on=Activar", "-A", "no=Ahora no", title, body];
        asker.running = true;
        return true;
    }
    Process {
        id: asker
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "on")
                    return;
                if (asker.kind === "shinobi-battery") {
                    if (root.lowForAuto)
                        root.on("battery " + Math.round(Power.percent * 100) + " %");
                } else if (root.games) {
                    root.wantAuto = true;     // still a game running: an Oni that GameMode will end
                    root.request("oni", "auto");
                }
            }
        }
    }

    // ── 忍 automatic triggers ───────────────────────────────────────────────────────────────────
    // battery ≤ threshold: once per discharge (dismissing or leaving by hand is respected until the next charge)
    property bool autoDone: false
    readonly property bool lowForAuto: Power.hasBattery && Power.onBattery && Settings.data.power.autoShinobiAt > 0
                                       && Power.percent * 100 <= Settings.data.power.autoShinobiAt
    onLowForAutoChanged: if (lowForAuto) Qt.callLater(autoCheck)
    function autoCheck(): void {
        if (!lowForAuto || autoDone || state !== "normal" || !loaded)
            return;
        if (!Settings.data.power.autoShinobiAsk) {
            autoDone = true;
            on("battery " + Math.round(Power.percent * 100) + " %");
            return;
        }
        autoDone = ask("shinobi-battery", "Batería al " + Math.round(Power.percent * 100) + " %",
            "¿Entrar en 忍 Shinobi? Pantalla a 60 Hz, sin animaciones ni turbo, Bluetooth apagado.");
    }
    Connections {
        target: Power
        function onOnBatteryChanged() {
            if (Power.onBattery) {
                // 鬼: full speed only on AC (the helper refuses it anyway); back when the charger returns
                if (root.oni && root.prev?.fan)
                    PowerCtl.run(["fan", "auto"], null);
                return;
            }
            if (root.oni && root.prev?.fan)
                PowerCtl.run(["fan", "full"], null);
            root.autoDone = false;
            if (asker.running && (asker.kind === "shinobi-battery" || asker.kind === "battery")) {
                asker.running = false;        // the question no longer applies
                if (asker.kind === "battery" && root.games && root.state === "normal") {
                    root.wantAuto = true;     // a game asked for Oni while unplugged: on AC that is a yes
                    root.request("oni", "auto");
                }
            }
            if (Settings.data.power.exitShinobiOnAC && (root.shinobi || root.want === "shinobi"
                                                        || (root.busy && root.target === "shinobi")))
                root.off("AC");               // queued if a transition is running, forgotten if only queued
        }
    }

    // ── start-up: an active snapshot resumes its mode (after a crash, a reload, a re-login or a reboot) ──
    property bool loaded: false
    property var readTexts: ({})            // file → text, until both snapshots have been read (or found missing)
    FileView {
        id: store
        path: root.snapshotPath
        printErrors: false
        atomicWrites: true
        onLoaded: root.snapshotRead("shinobi", text())
        onLoadFailed: root.snapshotRead("shinobi", "")
        onSaveFailed: Health.fail("Shinobi", "no se pudo guardar " + root.snapshotPath)
    }
    FileView {
        id: oniStore
        path: root.oniSnapshotPath
        printErrors: false
        atomicWrites: true
        onLoaded: root.snapshotRead("oni", text())
        onLoadFailed: root.snapshotRead("oni", "")
        onSaveFailed: Health.fail("Oni", "no se pudo guardar " + root.oniSnapshotPath)
    }
    function snapshotRead(m: string, text: string): void {
        if (loaded || m in readTexts)
            return;
        const t = Object.assign({}, readTexts);
        t[m] = text;
        readTexts = t;
        if ("shinobi" in t && "oni" in t)
            resume();
    }
    function parsed(text: string): var {
        try {
            const d = JSON.parse(text);
            return d && d.active === true ? d : null;
        } catch (e) {
            return null;
        }
    }
    // both files read: an active one resumes its mode. Two active ones (a crash in the middle of a change) cannot both
    // be true: the newer wins, the older is marked inactive and reported (what it changed is the newer one's base now)
    function resume(): void {
        let sh = parsed(readTexts.shinobi), on = parsed(readTexts.oni);
        if (sh && on) {
            const older = String(sh.at) < String(on.at) ? "shinobi" : "oni";
            Health.fail(older === "oni" ? "Oni" : "Shinobi", "había dos modos activos a la vez: se queda el más reciente");
            save(older, { mode: older, active: false, at: new Date().toISOString(), reason: "dos modos activos" });
            if (older === "oni")
                on = null;
            else
                sh = null;
        }
        const d = on ?? sh;
        if (d) {
            prev = d;
            phase = "on";
            if (d === on) {
                state = "oni";
                logMode = "oni";
                Displays.refreshMax = true;
                Displays.vrrOnDemand = !!oniCfg.vrrGames;
                log("resumed from " + oniSnapshotPath);
                Qt.callLater(reapplyOni);
            } else {
                state = "shinobi";
                logMode = "shinobi";
                ThemeCtl.hold("shinobi");
                Displays.refreshCap = Object.keys(d.refresh ?? {}).length > 0 ? 60 : 0;
                log("resumed from " + snapshotPath);
                Qt.callLater(reapply);
            }
        }
        readTexts = ({});
        loaded = true;
        Qt.callLater(autoCheck);
        // what was asked before the files were read (GameMode, a key at start-up)
        const w = want, r = wantReason;
        want = "";
        wantReason = "";
        if (w !== "" && w !== state)
            Qt.callLater(() => root.request(w, r || "en cola"));
    }
    // what lives in the kernel or in daemons is gone after a reboot: put it again (each step is idempotent)
    function reapply(): void {
        const s = prev;
        if (!s || !shinobi)
            return;
        if (s.onBattery && Power.available && !Power.onBattery && Settings.data.power.exitShinobiOnAC) {
            off("AC");                        // unplugged when it started, plugged in now
            return;
        }
        writeNiri("shinobi", true);
        Brightness.clampAll();
        if (Power.profile !== "power-saver")
            Power.setProfile("power-saver", true);
        if (s.boostOff)
            PowerCtl.run(["boost", "off"], null);
        if (s.gpu)
            PowerCtl.run(["gpu", "low"], null);
        for (const i of (s.wifiOff ?? []))
            PowerCtl.run(["wifi-ps", "on", i], null);
        if (s.kbd > 0)
            KbdLight.set(0);
    }
    // an Oni that GameMode started ends if no game runs any more (a reboot, a crash of the game during a reload)
    function reapplyOni(): void {
        const s = prev;
        if (!s || !oni)
            return;
        if (s.auto) {
            gmCheck.running = true;
            return;
        }
        reapplyOniSteps();
    }
    function reapplyOniSteps(): void {
        const s = prev;
        if (!s || !oni)
            return;
        writeNiri("oni", true);
        if (s.scx)
            PowerCtl.run(["scx", "lavd"], null);
        if (Power.profile !== "performance")
            Power.setProfile("performance", true);
        if (s.boostOff)
            PowerCtl.run(["boost", "off"], null);
        if (s.gpu)
            PowerCtl.run(["gpu", gpuWanted || "high"], null);
        for (const i of (s.wifiOn ?? []))
            PowerCtl.run(["wifi-ps", "off", i], null);
        if (s.fan && !Power.onBattery)
            PowerCtl.run(["fan", "full"], null);
    }
    Process {
        id: gmCheck
        command: ["sh", "-c", "command -v gamemoded >/dev/null || exit 3; gamemoded -s"]
        stdout: StdioCollector { id: gmOut }
        onExited: code => {
            if (!root.oni)
                return;
            if (code === 3) {                 // no GameMode any more: keep it as a manual Oni
                Health.fail("Oni", "gamemoded no está: Oni sigue como manual");
                root.reapplyOniSteps();
            } else if (/is active/.test(gmOut.text)) {
                root.games = true;
                root.reapplyOniSteps();
            } else {
                root.request("normal", "juego cerrado");
            }
        }
    }
}
