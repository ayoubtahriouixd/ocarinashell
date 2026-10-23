pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 配置 Haichi — screens (docs/07-IDEAS, mockup 12). The ONLY owner of ~/.local/state/ocarinashell/niri/outputs.kdl
// (rendered here, validated and installed atomically by bin/ocarina-niri-gen). Every change made by hand is a trial:
// it is applied at once and reverts by itself after 15 s unless «Mantener». Profiles are stored per set of monitors
// (huella = fabricante|modelo|serie of each, sorted) and applied by themselves when that set is connected.
// Safety: if the screens that remain are all configured off (e.g. «Solo monitor» and the monitor is unplugged), the
// laptop panel is switched back on at once — the session can never end up dark. The trial does not live only in this
// process: bin/ocarina-niri-gen keeps the known-good file and arms a systemd timer that restores it after 17 s even
// if the shell crashes or reloads; at start-up an orphaned trial is restored. Outputs are re-read after every write
// and on DRM hot-plug (udev events: a monitor configured «off» creates no wl_output).
// 発表 Happyō («Duplicar»): niri does not clone outputs, so wl-mirror shows the primary full screen on the other one,
// with No molestar + Despierto + notifications without content; it ends from the island, Esc on the copy, or when
// a screen goes away.
Singleton {
    id: root

    // ── model ──────────────────────────────────────────────────────────────────────────────────
    property var fake: null                 // tests/captures: a simulated external monitor (nothing is written)
    readonly property var source: fake ? Object.assign({}, Niri.outputs, fake) : Niri.outputs
    readonly property var list: {
        const out = [];
        for (const name in source) {
            const o = source[name];
            const modes = (o.modes ?? []).map((m, i) => ({ i: i, w: m.width, h: m.height, r: m.refresh_rate, pref: !!m.is_preferred }));
            const cur = o.current_mode !== null && o.current_mode !== undefined ? modes[o.current_mode] : null;
            const ps = o.physical_size ?? [0, 0];
            const internal = Brightness.isInternal(name);
            const key = [o.make ?? "", (o.model ?? "").trim(), o.serial ?? ""].join("|");
            const alias = Settings.data.display.brightness.perOutput[key]?.alias;
            out.push({
                name: name, key: key, make: o.make ?? "", model: (o.model ?? "").trim(), internal: internal,
                modes: modes, cur: cur, enabled: !!o.logical,
                x: o.logical?.x ?? 0, y: o.logical?.y ?? 0, lw: o.logical?.width ?? 0, lh: o.logical?.height ?? 0,
                scale: o.logical?.scale ?? 1, transform: o.logical?.transform ?? "Normal",
                // niri reports vrr_enabled only while it is active: on-demand VRR is read from our own file
                vrrSupported: !!o.vrr_supported, vrr: !!o.vrr_enabled || root.fileVrr(name),
                inches: ps[0] > 0 ? Math.round(Math.hypot(ps[0], ps[1]) / 25.4) : 0,
                label: internal ? "Portátil" : alias || (ps[0] > 0 ? "Monitor " + Math.round(Math.hypot(ps[0], ps[1]) / 25.4) + "″" : "Monitor " + name)
            });
        }
        // physical order: left to right (as niri lays them out), disabled ones last
        return out.sort((a, b) => (b.enabled - a.enabled) || (a.x - b.x) || a.name.localeCompare(b.name));
    }
    readonly property int count: list.length
    readonly property bool multi: count > 1
    readonly property var internal: list.find(o => o.internal) ?? null
    readonly property var externals: list.filter(o => !o.internal)
    readonly property string fingerprint: list.map(o => o.key).sort().join("+")
    readonly property var profiles: Settings.data.display.profiles ?? {}
    readonly property var activeProfile: profiles[fingerprint] ?? null
    function byName(n: string): var {
        return list.find(o => o.name === n) ?? null;
    }

    // primary: the profile's choice (by key), else the laptop panel, else the first screen
    readonly property string primary: {
        const p = activeProfile;
        if (p) {
            for (const k in p.outputs) {
                if (p.outputs[k].primary) {
                    const o = list.find(x => x.key === k && x.enabled);
                    if (o)
                        return o.name;
                }
            }
        }
        const i = list.find(o => o.internal && o.enabled);
        return i ? i.name : (list.find(o => o.enabled)?.name ?? (Quickshell.screens[0]?.name ?? ""));
    }

    // the layout mode the current state looks like
    readonly property string mode: mirroring ? "mirror"
        : !multi ? "internal"
        : internal && !internal.enabled ? "external"
        : externals.every(o => !o.enabled) ? "internal" : "extend"

    // ── rendering ──────────────────────────────────────────────────────────────────────────────
    function modeStr(m: var): string {
        return m.w + "x" + m.h + "@" + (m.r / 1000).toFixed(3);
    }
    // ── 忍 Shinobi: refresh ceiling for the laptop panel (Modes) ──────────────────────────────────
    // While refreshCap > 0 every write keeps the panel at the fastest mode ≤ cap with the same size (a reload of niri
    // or a profile cannot bring 120 Hz back). capRefresh() returns the modes it replaced so Modes can snapshot them;
    // uncapRefresh() puts them back (or the fastest mode of the current size if that one is gone).
    property real refreshCap: 0
    property bool vrrAlways: false          // with the cap: VRR always on (the panel idles at its minimum, 30 Hz)
    // modes written by uncapRefresh() that niri has not reported back yet (a re-entry right after leaving must see
    // them, not the stale capped ones); forgotten when the outputs are read again
    property var justWritten: ({})
    onSourceChanged: justWritten = ({})
    // ── 鬼 Oni: the opposite — the panel at its fastest mode of the same size, with on-demand VRR so the per-window
    // rules of oni.kdl (games) can use it; boostRefresh()/releaseRefresh() snapshot and restore like the ceiling
    property bool refreshMax: false
    property bool vrrOnDemand: false
    function capped(o: var, m: var): var {
        if ((refreshCap <= 0 && !refreshMax) || !o || !o.internal || !m)
            return m;
        const fit = o.modes.filter(x => x.w === m.w && x.h === m.h && (refreshMax || x.r <= refreshCap * 1000 + 500))
                           .sort((a, b) => b.r - a.r)[0];
        return fit ?? m;
    }
    function boostRefresh(vrr: bool): var {
        refreshMax = true;
        vrrOnDemand = vrr;
        if (trial)
            keep();                         // a running trial would put its older file back over this write
        const saved = {};
        const cfg = liveCfg();
        for (const o of list) {
            const c = cfg[o.name];
            if (!o.internal || !c.enabled || !c.mode)
                continue;
            if (justWritten[o.name]) {
                c.mode = justWritten[o.name].mode;
                c.vrr = justWritten[o.name].vrr;
            }
            const m = capped(o, c.mode);
            if (m.r !== c.mode.r || (vrr && o.vrrSupported && !c.vrr))
                saved[o.name] = { w: c.mode.w, h: c.mode.h, r: c.mode.r, vrr: !!c.vrr };
        }
        if (Object.keys(saved).length > 0)
            write(render(cfg), "plain");
        return saved;
    }
    function capRefresh(hz: real, vrr: bool): var {
        refreshCap = hz;
        vrrAlways = vrr;
        const saved = {};
        const cfg = liveCfg();
        for (const o of list) {
            const c = cfg[o.name];
            if (!o.internal || !c.enabled || !c.mode)
                continue;
            if (justWritten[o.name])
                c.mode = justWritten[o.name].mode;
            if (justWritten[o.name])
                c.vrr = justWritten[o.name].vrr;
            const m = capped(o, c.mode);
            if ((m !== c.mode && m.r !== c.mode.r) || (vrr && o.vrrSupported))
                saved[o.name] = { w: c.mode.w, h: c.mode.h, r: c.mode.r, vrr: !!c.vrr };
        }
        if (Object.keys(saved).length > 0)
            write(render(cfg), "plain");
        else {
            refreshCap = 0;                 // nothing to change (no VRR on this panel): no ceiling left set
            vrrAlways = false;
        }
        return saved;
    }
    function uncapRefresh(saved: var): void {
        releaseRefresh(saved);
    }
    // ends the ceiling (Shinobi) or the boost (Oni) and puts the saved modes back
    function releaseRefresh(saved: var): void {
        const forced = vrrAlways || vrrOnDemand;
        refreshCap = 0;
        vrrAlways = false;
        refreshMax = false;
        vrrOnDemand = false;
        if (trial)
            keep();                         // a running trial would put its older file back over this write
        const cfg = liveCfg();
        let touched = forced;
        for (const o of list) {
            const c = cfg[o.name];
            if (!o.internal || !c.enabled || !c.mode)
                continue;
            const s = saved?.[o.name];
            if (s && s.vrr !== undefined)
                c.vrr = s.vrr;              // the file says «VRR» while forced: the old on-demand/off comes back
            const same = o.modes.filter(x => x.w === c.mode.w && x.h === c.mode.h);
            const m = (s ? same.find(x => x.w === s.w && x.h === s.h && Math.abs(x.r - s.r) < 500) : null)
                ?? (s ? same.sort((a, b) => b.r - a.r)[0] : null);
            if (m && m.r !== c.mode.r) {
                c.mode = m;
                touched = true;
            }
        }
        if (touched) {
            const jw = {};
            for (const n in cfg)
                if (cfg[n].mode)
                    jw[n] = { mode: cfg[n].mode, vrr: !!cfg[n].vrr };
            write(render(cfg), "plain");
            justWritten = jw;
        }
    }

    // cfg: name → { enabled, mode {w,h,r}, scale, transform, x, y, vrr, primary }
    function render(cfg: var): string {
        const L = ["// GENERATED — owner: Displays (配置 Haichi). Do not edit by hand: Ajustes → Pantalla rewrites it.",
                   "// This is the ONLY file with output blocks (niri does not merge them: the first match wins).",
                   "// Written by connector name for the screens connected now; a profile rewrites it on hot-plug.", ""];
        for (const name of Object.keys(cfg).sort()) {
            const c = cfg[name];
            if (!/^[A-Za-z0-9_-]+$/.test(name))
                continue;
            // values may come from settings.json (profiles, an imported file): only known words and finite numbers
            const tr = String(c.transform ?? "normal").toLowerCase();
            c.transform = transforms.indexOf(tr) >= 0 ? tr : "normal";
            c.scale = Number.isFinite(Number(c.scale)) ? Math.max(0.5, Math.min(4, Number(c.scale))) : 1;
            c.x = Number.isFinite(Number(c.x)) ? Number(c.x) : 0;
            c.y = Number.isFinite(Number(c.y)) ? Number(c.y) : 0;
            if (c.mode && !(Number.isFinite(c.mode.w) && Number.isFinite(c.mode.h) && Number.isFinite(c.mode.r)))
                c.mode = null;
            if (!c.enabled) {
                L.push("output \"" + name + "\" {", "    off", "}");
                continue;
            }
            L.push("output \"" + name + "\" {");
            const m = capped(byName(name), c.mode);
            if (m)
                L.push("    mode \"" + modeStr(m) + "\"");
            L.push("    scale " + Number(c.scale).toFixed(2).replace(/0$/, ""));
            L.push("    transform \"" + String(c.transform).toLowerCase() + "\"");
            L.push("    position x=" + Math.round(c.x) + " y=" + Math.round(c.y));
            const ob = byName(name);
            if (refreshCap > 0 && vrrAlways && ob?.internal && ob?.vrrSupported)
                L.push("    variable-refresh-rate");              // 忍 Shinobi: idles at the panel's minimum
            else if (c.vrr || (refreshMax && vrrOnDemand && ob?.internal && ob?.vrrSupported))
                L.push("    variable-refresh-rate on-demand=true");
            if (c.primary)
                L.push("    focus-at-startup");
            L.push("}");
        }
        return L.join("\n") + "\n";
    }
    readonly property var transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
    // the live state as a cfg
    function liveCfg(): var {
        const cfg = {};
        for (const o of list)
            cfg[o.name] = { enabled: o.enabled, mode: o.cur, scale: o.scale, transform: o.transform, x: o.x, y: o.y,
                            vrr: o.vrr, primary: o.name === primary };
        return cfg;
    }
    // logical size of a screen with a given mode/scale/transform
    function logicalSize(c: var): var {
        if (!c.mode)
            return { w: 0, h: 0 };
        const rot = /90|270/.test(String(c.transform));
        const w = Math.round((rot ? c.mode.h : c.mode.w) / c.scale), h = Math.round((rot ? c.mode.w : c.mode.h) / c.scale);
        return { w: w, h: h };
    }
    // enabled screens placed side by side in their current x order, top-aligned, no gaps
    function packRow(cfg: var): var {
        const names = Object.keys(cfg).filter(n => cfg[n].enabled).sort((a, b) => cfg[a].x - cfg[b].x || a.localeCompare(b));
        let x = 0;
        for (const n of names) {
            cfg[n].x = x;
            cfg[n].y = 0;
            x += logicalSize(cfg[n]).w;
        }
        return cfg;
    }

    // ── trial (revertir en 15 s) ─────────────────────────────────────────────────────────────────
    property bool trial: false
    property int countdown: 0
    property string trialLabel: ""
    property string error: ""
    property bool busy: gen.running

    function change(label: string, cfg: var): void {
        error = "";
        trial = true;
        trialLabel = label;
        countdown = 15;
        tick.restart();
        write(render(ensureVisible(cfg)), "trial");
        // nobody may be looking at Ajustes → Pantalla (a notification, IPC, a profile): ask where it can be answered
        if (!(Settei.open && Settei.page === "pantalla"))
            askTrial();
    }
    function keep(): void {
        tick.stop();
        trial = false;
        countdown = 0;
        Quickshell.execDetached([Paths.bin + "/ocarina-niri-gen", "trial-end", "outputs"]);
        // the profile of this set of monitors follows what was kept
        if (activeProfile)
            Qt.callLater(() => root.updateProfile(root.activeProfile.name, root.activeProfile.kanji));
    }
    function revert(): void {
        tick.stop();
        trial = false;
        countdown = 0;
        restorer.running = true;
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0)
                root.revert();
        }
    }
    Process {
        id: restorer
        command: [Paths.bin + "/ocarina-niri-gen", "restore", "outputs"]
        onExited: root.refreshSoon()
    }
    // start-up: a trial left behind by a crash or a reload (and its timer gone) goes back at once
    Process {
        running: true
        command: ["sh", "-c", 'f="$1/niri/outputs.kdl.trial"; [ -f "$f" ] || exit 0; '
                  + 'systemctl --user -q is-active ocarina-haichi-revert.timer && exit 0; exec "$2" restore outputs',
                  "sh", Paths.state, Paths.bin + "/ocarina-niri-gen"]
    }
    // «Mantener / Revertir» outside Settei: a notification with both actions (no answer = revert at 15 s)
    function askTrial(): void {
        if (trialAsk.running)
            return;
        trialAsk.command = ["notify-send", "-a", "OcarinaShell", "-i", "video-display", "-u", "critical", "-t", "15000",
                            "-A", "keep=Mantener", "-A", "revert=Revertir",
                            trialLabel, "Se revierte sola en 15 s si no confirmas."];
        trialAsk.running = true;
    }
    Process {
        id: trialAsk
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.trim();
                if (a === "keep" && root.trial)
                    root.keep();
                else if (a === "revert" && root.trial)
                    root.revert();
            }
        }
    }
    // a config where nothing is on is never written: the laptop panel (or the first screen) stays on
    function ensureVisible(cfg: var): var {
        const names = Object.keys(cfg);
        if (names.length > 0 && !names.some(n => cfg[n].enabled)) {
            const n = internal && cfg[internal.name] ? internal.name : names[0];
            const o = byName(n);
            cfg[n].enabled = true;
            cfg[n].mode = cfg[n].mode ?? (o ? (o.modes.find(x => x.pref) ?? o.modes[0]) : null);
            packRow(cfg);
        }
        return cfg;
    }
    // after any change of the real outputs: if every connected screen is off, switch the panel on (also during and
    // after a revert, e.g. «Solo monitor» restored after its monitor was unplugged)
    onListChanged: {
        safety.restart();
        if (mirrorPending !== "" && byName(mirrorPending)?.enabled)
            launchMirror();
    }
    Timer {
        id: safety
        interval: 700
        onTriggered: {
            if (root.fake || root.list.length === 0 || root.list.some(o => o.enabled))
                return;
            console.warn("Displays: ninguna pantalla encendida → se enciende", root.internal?.name ?? root.list[0].name);
            if (root.trial) {
                tick.stop();
                root.trial = false;
                Quickshell.execDetached([Paths.bin + "/ocarina-niri-gen", "trial-end", "outputs"]);
            }
            root.write(root.render(root.ensureVisible(root.liveCfg())), "plain");
        }
    }

    // ── edits from the page ────────────────────────────────────────────────────────────────────
    function setOutput(name: string, patch: var, label: string): void {
        const cfg = liveCfg();
        if (!cfg[name])
            return;
        Object.assign(cfg[name], patch);
        if (patch.primary === true)
            for (const n in cfg)
                cfg[n].primary = n === name;
        // a new size changes the neighbours' places: keep the row packed
        if ("mode" in patch || "scale" in patch || "transform" in patch || "enabled" in patch)
            packRow(cfg);
        change(label, cfg);
    }
    function move(name: string, x: real, y: real): void {
        const cfg = liveCfg();
        if (!cfg[name])
            return;
        cfg[name].x = Math.round(x);
        cfg[name].y = Math.round(y);
        // niri wants non-negative-ish layouts: shift everything so the top-left screen sits at 0,0
        const en = Object.keys(cfg).filter(n => cfg[n].enabled);
        const minX = Math.min(...en.map(n => cfg[n].x)), minY = Math.min(...en.map(n => cfg[n].y));
        for (const n of en) {
            cfg[n].x -= minX;
            cfg[n].y -= minY;
        }
        change("Posición de " + (byName(name)?.label ?? name), cfg);
    }
    function setMode(m: string): void {
        if (m === "mirror") {
            startMirror();
            return;
        }
        if (mirroring)
            stopMirror();
        if (!multi)
            return;
        const cfg = liveCfg();
        for (const o of list) {
            if (m === "extend")
                cfg[o.name].enabled = true;
            else if (m === "external")
                cfg[o.name].enabled = !o.internal;
            else if (m === "internal")
                cfg[o.name].enabled = o.internal;
            if (cfg[o.name].enabled && !cfg[o.name].mode)
                cfg[o.name].mode = o.modes.find(x => x.pref) ?? o.modes[0];
        }
        packRow(cfg);
        change(m === "extend" ? "Extender" : m === "external" ? "Solo monitor" : "Solo portátil", cfg);
    }

    // recommended scale: target ~110 logical px per inch-ish density (OLED 14″ 2880 → 1.75; 27″ 4K → 1.5)
    function recommendedScale(o: var): real {
        if (!o.cur || o.inches <= 0)
            return 1;
        // laptops are seen closer than desk monitors: ~138 px per logical inch vs ~110
        // (14″ 2880×1800 → 1,75 · 27″ 4K → 1,5 · 24″ 1080p → 1)
        const ppi = Math.hypot(o.cur.w, o.cur.h) / o.inches;
        const s = ppi / (o.internal ? 138 : 110);
        return Math.max(1, Math.min(3, Math.round(s * 4) / 4));
    }

    // ── profiles ───────────────────────────────────────────────────────────────────────────────
    function profileCfg(p: var): var {
        const cfg = {};
        for (const o of list) {
            const c = p.outputs[o.key];
            if (!c) {
                cfg[o.name] = { enabled: true, mode: o.modes.find(x => x.pref) ?? o.cur, scale: recommendedScale(o),
                                transform: "normal", x: 100000, y: 0, vrr: false, primary: false };
                continue;
            }
            const m = o.modes.find(x => x.w === c.mode?.w && x.h === c.mode?.h && Math.abs(x.r - c.mode?.r) < 500) ?? o.modes.find(x => x.pref) ?? o.cur;
            cfg[o.name] = { enabled: c.enabled, mode: m, scale: c.scale, transform: c.transform, x: c.x, y: c.y,
                            vrr: c.vrr && o.vrrSupported, primary: !!c.primary };
        }
        return ensureVisible(cfg);
    }
    function updateProfile(name: string, kanji: string): void {
        const outs = {};
        const cfg = liveCfg();
        for (const n in Modes.refreshSaved) {
            const r = Modes.refreshSaved[n];
            if (cfg[n] && cfg[n].mode && cfg[n].mode.w === r.w && cfg[n].mode.h === r.h)
                cfg[n].mode = { w: r.w, h: r.h, r: r.r };
            if (cfg[n] && r.vrr !== undefined)
                cfg[n].vrr = r.vrr;
        }
        for (const o of list) {
            const c = cfg[o.name];
            outs[o.key] = { enabled: c.enabled, mode: c.mode ? { w: c.mode.w, h: c.mode.h, r: c.mode.r } : null, scale: c.scale,
                            transform: String(c.transform).toLowerCase(), x: c.x, y: c.y, vrr: c.vrr, primary: c.primary };
        }
        const p = Object.assign({}, profiles);
        p[fingerprint] = { name: name || "Perfil", kanji: kanji || "家", outputs: outs, saved: new Date().toISOString() };
        Settings.set("display.profiles", p);
    }
    function deleteProfile(fp: string): void {
        const p = Object.assign({}, profiles);
        delete p[fp];
        Settings.set("display.profiles", p);
    }
    function applyProfile(fp: string): void {
        const p = profiles[fp];
        if (!p || fp !== fingerprint)
            return;
        const cfg = profileCfg(p);
        // a profile that switches the panel off is applied as a visible trial: the monitor may show nothing
        // (asleep, a dock without signal) and nobody could then confirm anything
        if (internal && cfg[internal.name] && !cfg[internal.name].enabled && internal.enabled)
            change("Perfil " + p.name + ": solo el monitor", cfg);
        else
            write(render(cfg), "plain");
    }

    // ── hot-plug ───────────────────────────────────────────────────────────────────────────────
    property string lastFingerprint: ""
    property var lastNames: []
    onFingerprintChanged: plugTimer.restart()
    Timer {
        id: plugTimer
        interval: 600                       // let niri finish announcing every output
        onTriggered: root.onPlug()
    }
    function onPlug(): void {
        if (fake || Object.keys(Niri.outputs).length === 0)
            return;
        const before = lastNames;
        lastNames = list.map(o => o.name);
        const first = lastFingerprint === "";
        lastFingerprint = fingerprint;
        if (mirroring && !multi)
            stopMirror();
        if (trial) {
            revert();                       // a cable pulled during a trial: back to the known-good file
            return;                         // (the safety timer still checks what is on once niri re-reads it)
        }
        if (first)
            return;
        if (activeProfile && Settings.data.display.autoProfile) {
            applyProfile(fingerprint);
            Osd.show("info", 0, activeProfile.kanji + " Perfil " + activeProfile.name, "monitor");
            return;
        }
        const added = list.filter(o => !o.internal && before.indexOf(o.name) < 0);
        if (added.length > 0 && Settings.data.display.notifyOnConnect)
            askConnect(added[0]);
    }
    // «Monitor 27″ conectado · Extender · Solo este · Duplicar · Organizar» (a normal notification with actions)
    function askConnect(o: var): void {
        if (asker.running)
            return;
        asker.command = ["notify-send", "-a", "OcarinaShell", "-i", "video-display", "-u", "normal", "-t", "20000",
                         "-A", "extend=Extender", "-A", "external=Solo este", "-A", "mirror=Duplicar", "-A", "arrange=Organizar",
                         o.label + " conectado", "¿Cómo lo usamos? Guarda un perfil y la próxima vez se aplica solo."];
        asker.running = true;
    }
    Process {
        id: asker
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.trim();
                if (a === "arrange")
                    Settei.show("pantalla");
                else if (a === "extend" || a === "external" || a === "mirror")
                    root.setMode(a);
            }
        }
    }

    // ── 発表 Happyō: duplicate = wl-mirror of the primary, full screen on the other screen ─────────
    // DND / Despierto before presenting are kept in Settings (display.mirrorBefore): a reload or crash in the middle
    // must not leave No molestar on for ever. A screen switched on only for the copy is switched off again after.
    property bool mirrorAvailable: false
    property bool mirroring: mirror.running
    property string mirrorTarget: ""
    property string mirrorPending: ""        // target waiting for niri to switch it on
    property bool mirrorTurnedOn: false
    function startMirror(): void {
        if (mirror.running || !multi || !mirrorAvailable)
            return;
        const src = primary;
        const target = list.find(o => o.name !== src) ?? null;
        if (!target)
            return;
        if (!Settings.data.display.mirrorBefore)
            Settings.set("display.mirrorBefore", { dnd: Settings.data.notifications.dnd, awake: Idle.inhibit });
        if (Settings.data.display.mirrorDnd && !Settings.data.notifications.dnd)
            Settings.set("notifications.dnd", true);
        if (!Idle.inhibit)
            Idle.toggleInhibit();
        mirrorTarget = target.name;
        if (!target.enabled) {
            // the copy needs its screen on: wl-mirror starts once niri reports it on (outputs re-read after the write)
            const cfg = liveCfg();
            cfg[target.name].enabled = true;
            cfg[target.name].mode = target.modes.find(x => x.pref) ?? target.modes[0];
            mirrorTurnedOn = true;
            mirrorPending = target.name;
            write(render(packRow(cfg)), "plain");
            return;
        }
        launchMirror();
    }
    function launchMirror(): void {
        const t = byName(mirrorTarget);
        mirrorPending = "";
        if (!t || !t.enabled)
            return;
        mirror.command = ["wl-mirror", "--fullscreen-output", t.name, "--title", "OcarinaShell · Presentar", primary];
        mirror.running = true;
        Osd.show("info", 0, "発表 Presentando en " + t.label + " · Esc en la copia para salir", "cast");
    }
    function stopMirror(): void {
        if (mirror.running)
            mirror.signal(15);
        else
            restoreAfterMirror();
    }
    function restoreAfterMirror(): void {
        const b = Settings.data.display.mirrorBefore;
        if (b) {
            if (!b.dnd && Settings.data.notifications.dnd)
                Settings.set("notifications.dnd", false);
            if (!b.awake && Idle.inhibit)
                Idle.toggleInhibit();
            Settings.set("display.mirrorBefore", null);
        }
        if (mirrorTurnedOn && mirrorTarget !== "" && byName(mirrorTarget)?.enabled && multi) {
            const cfg = liveCfg();
            cfg[mirrorTarget].enabled = false;
            write(render(ensureVisible(packRow(cfg))), "plain");
        }
        mirrorTurnedOn = false;
        mirrorTarget = "";
        mirrorPending = "";
    }
    Process {
        id: mirror
        onExited: root.restoreAfterMirror()
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v wl-mirror"]
        onExited: code => root.mirrorAvailable = code === 0
    }
    // a presentation cut by a reload/crash: put DND and Despierto back as they were
    Connections {
        target: Settings
        function onReadyChanged() {
            if (Settings.ready && Settings.data.display.mirrorBefore && !mirror.running)
                root.restoreAfterMirror();
        }
    }
    Component.onCompleted: if (Settings.ready && Settings.data.display.mirrorBefore && !mirror.running) restoreAfterMirror()

    // ── 壱 弐 参 Identificar ─────────────────────────────────────────────────────────────────────
    readonly property var numerals: ["壱", "弐", "参", "肆", "伍", "陸"]
    property bool identifying: false
    function numeralOf(name: string): string {
        const i = list.findIndex(o => o.name === name);
        return i >= 0 ? numerals[i] ?? String(i + 1) : "";
    }
    function identify(): void {
        identifying = true;
        idTimer.restart();
    }
    Timer {
        id: idTimer
        interval: 2000
        onTriggered: root.identifying = false
    }

    // ── file io ────────────────────────────────────────────────────────────────────────────────
    property string fileText: ""
    function fileVrr(name: string): bool {
        const m = new RegExp('output "' + name.replace(/[^A-Za-z0-9_-]/g, "") + '" \\{([^}]*)\\}').exec(fileText);
        return !!m && /variable-refresh-rate/.test(m[1]);
    }
    FileView {
        id: file
        path: Paths.state + "/niri/outputs.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.fileText = text()
    }
    // kind: "trial" (keeps the known-good file + arms the 17 s systemd revert first) or "plain"
    property var queued: null
    function write(text: string, kind: string): void {
        if (fake) {
            console.info("Displays (simulado, " + kind + "):\n" + text);
            return;
        }
        if (gen.running) {
            queued = { text: text, kind: kind };
            return;
        }
        gen.kind = kind;
        gen.command = ["sh", "-c", (kind === "trial" ? '"$0" trial-start outputs >/dev/null && ' : "")
                       + 'printf "%s" "$1" | "$0" apply outputs', Paths.bin + "/ocarina-niri-gen", text];
        gen.running = true;
    }
    Process {
        id: gen
        property string kind: ""
        stderr: StdioCollector { id: genErr }
        onExited: code => {
            if (code !== 0) {
                root.error = genErr.text.trim() || "niri no aceptó la configuración";
                console.warn("Displays: outputs.kdl rechazado:", root.error);
                Health.fail("Haichi", root.error);
                // a rejected change inside a trial keeps the trial (and its countdown): earlier changes still revert
            } else {
                root.error = "";
            }
            root.refreshSoon();
            if (root.queued) {
                const q = root.queued;
                root.queued = null;
                root.write(q.text, q.kind);
            }
        }
    }
    // niri re-reads the include by itself; ask for the outputs again once it has (ConfigLoaded also triggers it)
    function refreshSoon(): void {
        refresh.restart();
    }
    Timer {
        id: refresh
        interval: 300
        onTriggered: Niri.refreshOutputs()
    }
    Connections {
        target: Niri
        function onConfigLoaded(failed) { root.refreshSoon(); }
    }
    // DRM hot-plug, also of monitors configured «off» (they create no wl_output): udev events, no polling
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=drm"]
        stdout: SplitParser {
            onRead: line => { if (/ change /.test(line)) root.refreshSoon(); }
        }
    }

    function status(): string {
        return JSON.stringify({ fingerprint: fingerprint, profile: activeProfile?.name ?? null, primary: primary, mode: mode,
                                trial: trial, countdown: countdown, mirroring: mirroring,
                                outputs: list.map(o => ({ name: o.name, label: o.label, enabled: o.enabled, x: o.x, y: o.y,
                                                          scale: o.scale, mode: o.cur ? modeStr(o.cur) : null })) });
    }
    // tests/captures (mockup 12): a 27″ 4K monitor on DP-1 to the left of the panel; nothing is written meanwhile
    function setFake(on: bool): void {
        fake = on ? { "DP-1": { name: "DP-1", make: "Dell Inc.", model: "U2723QE", serial: "SIMULADO",
                                physical_size: [597, 336], current_mode: 0, vrr_supported: true, vrr_enabled: false,
                                modes: [{ width: 3840, height: 2160, refresh_rate: 60000, is_preferred: true },
                                        { width: 3840, height: 2160, refresh_rate: 30000, is_preferred: false },
                                        { width: 2560, height: 1440, refresh_rate: 60000, is_preferred: false },
                                        { width: 1920, height: 1080, refresh_rate: 60000, is_preferred: false }],
                                logical: { x: -2560, y: -412, width: 2560, height: 1440, scale: 1.5, transform: "Normal" } } } : null;
    }
}
