pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Brightness per screen (D-009, docs/01-ARQUITECTURA §5). One entry per output:
//   { name, label, kind: internal|ddc|soft|none, pct, bus, key }
// - internal: backlight through brightnessctl (logind, no root).
// - ddc: external monitor over DDC/CI (ddcutil --bus N), one queue per bus, last value wins, ≥ 200 ms apart;
//   3 failures in a row → that screen falls back to software dimming.
// - soft: no DDC/CI → translucent black layer (ocarina-dim), max 60 % (never black).
// Detection only when Quickshell.screens changes (2 s later, in the background); zero ddcutil processes at rest.
// The map is mirrored to ~/.local/state/ocarinashell/brightness.json for the CLI fallback.
Singleton {
    id: root

    property var entries: []
    readonly property bool ddcAvailable: ddcCheck.found
    property string backlightDevice: ""

    signal changed(string name)

    function isInternal(name: string): bool {
        return /^(eDP|LVDS|DSI)-/.test(name);
    }
    function entry(name: string): var {
        return entries.find(e => e.name === name) ?? null;
    }
    function softLevel(name: string): real {
        const e = entry(name);
        return e && e.kind === "soft" ? e.pct : 100;
    }

    function targets(output: string): var {
        if (output === "all")
            return entries;
        let name = output;
        if (name === "") {
            const t = Settings.data.display.brightness.keysTarget;
            name = t === "internal" ? (entries.find(e => e.kind === "internal")?.name ?? "")
                 : t === "all" ? "all" : Niri.focusedOutput;
            if (name === "all")
                return entries;
        }
        const e = entry(name) ?? entries.find(x => x.kind === "internal");
        return e ? [e] : [];
    }

    function update(name: string, patch: var): void {
        entries = entries.map(e => e.name === name ? Object.assign({}, e, patch) : e);
        changed(name);
        persist();
    }

    function set(pct: real, output: string): void {
        const list = targets(output);
        for (const e of list) {
            apply(e, pct);
            learn(e.name);
        }
        if (list.length > 0) {
            const e = entry(list[0].name);
            Osd.show("brightness", (list.length === 1 ? e.pct : Math.max(0, Math.min(100, pct))) / 100,
                     list.length === 1 ? e.label : "Todas las pantallas", "light_mode");
        }
    }
    function step(delta: real, output: string): void {
        const list = targets(output);
        for (const e of list) {
            apply(e, e.pct + delta);
            learn(e.name);
        }
        if (list.length === 1) {
            const e = entry(list[0].name);
            Osd.show("brightness", e.pct / 100, e.label, "light_mode");
        } else if (list.length > 1) {
            Osd.show("brightness", entry(list[0].name).pct / 100, "Todas las pantallas", "light_mode");
        }
    }
    function increment(stepStr: string, output: string): void {
        step(Math.abs(parseFloat(stepStr) || 5), output);
    }
    function decrement(stepStr: string, output: string): void {
        step(-Math.abs(parseFloat(stepStr) || 5), output);
    }

    // ── 昼夜 brightness by the time of day (display.brightness.timeCurve) ─────────────────────────
    // Two stretches, day (sunrise → sunset, Kisetsu) and night. Moving a screen by hand stores that value for the
    // current stretch (so it holds until the next one); at each change of stretch every screen goes to its value
    // for the new one: one write per screen per transition (DDC: far below one a minute). Paused in Shinobi/Oni;
    // turning it on (or leaving those modes) applies the current stretch.
    readonly property bool curveOn: Settings.data.display.brightness.timeCurve && !Modes.shinobi && !Modes.oni
    property string stretch: ""
    property var learned: ({})            // key → { day, night } waiting to be persisted
    function currentStretch(): string {
        const now = Time.now.getTime(), rise = Kisetsu.sunrise.getTime(), set = Kisetsu.sunset.getTime();
        if (isNaN(rise) || isNaN(set)) {
            const h = Time.now.getHours();
            return h >= 7 && h < 20 ? "day" : "night";
        }
        return now >= rise && now < set ? "day" : "night";
    }
    function learn(name: string): void {
        if (!curveOn)
            return;
        const e = entry(name);
        if (!e)
            return;
        const k = outputKey(name);
        const l = Object.assign({}, learned);
        l[k] = Object.assign({}, l[k] ?? {}, { [stretch || currentStretch()]: e.pct });
        learned = l;
        saveLearned.restart();
    }
    Timer {
        id: saveLearned
        interval: 2000
        onTriggered: {
            const per = JSON.parse(JSON.stringify(Settings.data.display.brightness.perOutput));
            for (const k in root.learned)
                per[k] = Object.assign({}, per[k] ?? {}, root.learned[k]);
            root.learned = {};
            Settings.set("display.brightness.perOutput", per);
        }
    }
    function applyStretch(): void {
        stretch = currentStretch();
        const per = Settings.data.display.brightness.perOutput;
        for (const e of entries) {
            const v = per[outputKey(e.name)]?.[stretch];
            if (v !== undefined && Math.abs(v - e.pct) >= 1)
                apply(e, v);
        }
    }
    onCurveOnChanged: if (curveOn) applyStretch(); else stretch = ""
    Connections {
        target: root.curveOn ? Time : null
        function onMinuteTick() {
            if (root.currentStretch() !== root.stretch)
                root.applyStretch();
        }
    }

    // stable identity of a screen (fabricante|modelo|serie, as Settings perOutput/profiles use it)
    function outputKey(name: string): string {
        const o = Niri.outputs[name];
        return o ? [o.make ?? "", (o.model ?? "").trim(), o.serial ?? ""].join("|") : name;
    }
    function minFor(e: var): real {
        const m = Number(Settings.data.display.brightness.perOutput[outputKey(e.name)]?.min ?? 0);
        return Math.max(e.kind === "soft" ? 40 : 1, m || 0);
    }
    // Settei → «Detectar de nuevo»
    function detectAgain(): void {
        detectLater.stop();
        Qt.callLater(() => detectLater.triggered());
    }
    // ddc / soft fallback switched in Settei: rebuild the kinds
    readonly property string kindsKey: Settings.data.display.brightness.ddc + "," + Settings.data.display.brightness.softFallback
    onKindsKeyChanged: detectAgain()

    // 忍 Shinobi: ceilings (0 = none). Nothing goes above them (keys, sliders, undim, the curve).
    // brightnessCapExternal 100 = no ceiling on monitors (it is meant for USB-C screens fed by the laptop).
    readonly property real capInternal: Modes.shinobi ? Number(Settings.data.shinobi.brightnessCap) || 0 : 0
    readonly property real capExternal: Modes.shinobi && Number(Settings.data.shinobi.brightnessCapExternal) < 100
        ? Number(Settings.data.shinobi.brightnessCapExternal) : 0
    function capFor(e: var): real {
        const c = e.kind === "internal" ? capInternal : capExternal;
        return c > 0 ? c : 100;
    }
    // every screen above its ceiling goes down to it (entering Shinobi, a lower ceiling chosen in Settei)
    function clampAll(): void {
        for (const e of entries)
            if (e.pct > capFor(e))
                apply(e, e.pct);
        if (dimSaved !== null) {
            const d = Object.assign({}, dimSaved);
            for (const e of entries)
                if (d[e.name] !== undefined)
                    d[e.name] = Math.min(d[e.name], capFor(e));
            dimSaved = d;
        }
    }
    // the value a screen really has: under the idle dimming, the one it goes back to
    function realPct(name: string): real {
        const e = entry(name);
        return dimSaved !== null && dimSaved[name] !== undefined ? dimSaved[name] : (e ? e.pct : -1);
    }
    // put a value back; while dimmed, it becomes the one undim() returns to
    function restoreTo(name: string, pct: real): void {
        const e = entry(name);
        if (!e)
            return;
        if (dimSaved !== null && dimSaved[name] !== undefined) {
            const d = Object.assign({}, dimSaved);
            d[name] = pct;
            dimSaved = d;
        } else {
            apply(e, pct);
        }
    }
    function apply(e: var, pct: real): void {
        const v = Math.round(Math.max(minFor(e), Math.min(capFor(e), pct)));
        if (e.kind === "internal") {
            Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "--min-value=1%", "set", v + "%"]);
            update(e.name, { pct: v });
        } else if (e.kind === "ddc") {
            update(e.name, { pct: v });
            ddcWrite(e.bus, v, e.name);
        } else if (e.kind === "soft") {
            update(e.name, { pct: v });   // ocarina-dim follows softLevel()
        }
    }

    // ── idle dimming (Idle service): every screen to 30 % at most, each back to its own value on activity ──────
    // internal: stepped fade (one short shell loop); soft: the dim layer animates; DDC: a single write (slow bus).
    property var dimSaved: null           // name → pct before dimming
    readonly property bool dimmed: dimSaved !== null
    function dimAll(): void {
        if (dimSaved !== null)
            return;
        const saved = {};
        for (const e of entries) {
            saved[e.name] = e.pct;
            const target = Math.min(e.pct, 30);
            if (target >= e.pct)
                continue;
            if (e.kind === "internal") {
                const steps = [];
                for (let i = 1; i <= 8; i++)
                    steps.push(Math.round(e.pct + (target - e.pct) * i / 8));
                dimFade.command = ["sh", "-c", 'for v in "$@"; do brightnessctl -q -c backlight --min-value=1% set "$v%"; sleep 0.06; done',
                                   "sh"].concat(steps.map(String));
                dimFade.running = true;
            } else if (e.kind === "ddc") {
                ddcWrite(e.bus, target, e.name);
            }
            // never persisted: the remembered value stays the real one (soft dimming follows entries)
            updateQuiet(e.name, { pct: target });
        }
        dimSaved = saved;
    }
    function undim(): void {
        if (dimSaved === null)
            return;
        const saved = dimSaved;
        dimSaved = null;
        dimFade.running = false;          // activity during the fade: stop it before writing the real value
        for (const e of entries)
            if (saved[e.name] !== undefined && saved[e.name] !== e.pct)
                apply(e, saved[e.name]);
    }
    Process {
        id: dimFade
    }
    // like update() but not persisted: a dimmed value must never become the remembered one
    function updateQuiet(name: string, patch: var): void {
        entries = entries.map(e => e.name === name ? Object.assign({}, e, patch) : e);
        changed(name);
    }

    function list(): string {
        return JSON.stringify(entries.map(e => ({ name: e.name, label: e.label, kind: e.kind, pct: e.pct })));
    }

    // ── model rebuild (only on screen changes) ────────────────────────────────────────────────
    function labelFor(name: string, internal: bool): string {
        if (internal)
            return "Portátil";
        const o = Niri.outputs[name];
        const key = outputKey(name);
        const alias = Settings.data.display.brightness.perOutput[key]?.alias;
        if (alias)
            return alias;
        const ps = o?.physical_size;
        if (ps && ps[0] > 0)
            return "Monitor " + Math.round(Math.hypot(ps[0], ps[1]) / 25.4) + "″";
        return "Monitor " + name;
    }

    property var ddcMap: ({})   // connector name → { bus, key }

    function rebuild(): void {
        const old = {};
        for (const e of entries)
            old[e.name] = e;
        const out = [];
        for (const s of Quickshell.screens) {
            const name = s.name;
            const internal = isInternal(name);
            const d = ddcMap[name];
            const kind = internal ? "internal" : d ? "ddc" : Settings.data.display.brightness.softFallback ? "soft" : "none";
            const prev = old[name];
            out.push({
                name: name,
                label: labelFor(name, internal),
                kind: kind,
                pct: prev && prev.kind === kind ? prev.pct : (internal ? internalPct : kind === "ddc" ? d.pct ?? 100 : 100),
                bus: d ? d.bus : null,
                key: d ? d.key : name
            });
        }
        entries = out;
        persist();
    }

    property real internalPct: 100

    // written at most once a second (holding a brightness key must not hammer the disk)
    function persist(): void {
        persistLater.restart();
    }
    Timer {
        id: persistLater
        interval: 1000
        onTriggered: stateFile.setText(JSON.stringify({ updated: new Date().toISOString(), outputs: root.entries }, null, 1) + "\n")
    }

    // ── internal backlight ────────────────────────────────────────────────────────────────────
    Process {
        id: readInternal
        command: ["brightnessctl", "-m", "-c", "backlight"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0]?.split(",") ?? [];
                if (f.length >= 5) {
                    root.backlightDevice = f[0];
                    root.internalPct = parseInt(f[3]) || 100;
                    const e = root.entries.find(x => x.kind === "internal");
                    if (e && e.pct !== root.internalPct)
                        root.update(e.name, { pct: root.internalPct });
                }
                root.rebuild();
            }
        }
    }
    function refreshInternal(): void {
        readInternal.running = true;
    }

    // ── DDC/CI ────────────────────────────────────────────────────────────────────────────────
    Process {
        id: ddcCheck
        property bool found: false
        command: ["sh", "-c", "command -v ddcutil"]
        running: true
        onExited: code => found = code === 0
    }

    // Debounce hot-plug: detect 2 s after the last screen change, and only if there is an external screen.
    Timer {
        id: detectLater
        interval: 2000
        onTriggered: {
            const ext = Quickshell.screens.some(s => !root.isInternal(s.name));
            if (ext && ddcCheck.found && Settings.data.display.brightness.ddc) {
                if (detect.running)
                    root.redetect = true;     // a second hot-plug while detecting: run again afterwards
                else
                    detect.running = true;
            } else {
                root.ddcMap = {};
                root.rebuild();
            }
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.rebuild();          // soft entries appear at once; DDC follows after detection
            detectLater.restart();
        }
    }
    Component.onCompleted: detectLater.restart()
    Connections {
        target: Niri
        function onOutputsChanged() { root.rebuild(); }   // labels need make/model/physical size
    }

    property bool redetect: false

    // Tolerant parser of `ddcutil detect`: blocks start at column 0 ("Display N", "Invalid display", …)
    Process {
        id: detect
        command: ["timeout", "10", "ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                let cur = null;
                const flush = () => {
                    if (cur && cur.valid && cur.bus !== null && cur.connector)
                        map[cur.connector] = { bus: cur.bus, key: cur.monitor || cur.connector };
                };
                for (const line of text.split("\n")) {
                    if (/^\S/.test(line)) {
                        flush();
                        cur = { valid: /^Display\s+\d+/.test(line), bus: null, connector: "", monitor: "" };
                        continue;
                    }
                    if (!cur)
                        continue;
                    let m;
                    if ((m = /I2C bus:\s*\/dev\/i2c-(\d+)/.exec(line)))
                        cur.bus = parseInt(m[1]);
                    else if ((m = /DRM[ _]connector:\s*card\d+-(\S+)/.exec(line)))
                        cur.connector = m[1];
                    else if ((m = /Monitor:\s*(.+)$/.exec(line)))
                        cur.monitor = m[1].trim();
                }
                flush();
                root.ddcMap = map;
                root.readQueue = Object.keys(map);
                root.readNext();
                if (root.redetect) {
                    root.redetect = false;
                    detectLater.restart();
                }
            }
        }
    }

    // read the current value of each DDC monitor once after detection (one process at a time)
    property var readQueue: []
    function readNext(): void {
        if (readQueue.length === 0) {
            rebuild();
            return;
        }
        const name = readQueue[0];
        readQueue = readQueue.slice(1);
        getvcp.target = name;
        getvcp.command = ["timeout", "5", "ddcutil", "--bus", String(ddcMap[name].bus), "getvcp", "10", "--terse"];
        getvcp.running = true;
    }
    Process {
        id: getvcp
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                // "VCP 10 C 50 100"
                const m = /VCP\s+10\s+C\s+(\d+)\s+(\d+)/.exec(text);
                if (m && root.ddcMap[getvcp.target]) {
                    const mp = Object.assign({}, root.ddcMap);
                    mp[getvcp.target] = Object.assign({}, mp[getvcp.target],
                        { pct: Math.round(100 * parseInt(m[1]) / Math.max(1, parseInt(m[2]))) });
                    root.ddcMap = mp;
                }
                root.readNext();
            }
        }
    }

    // write queue per bus: { target, running, fails, name }
    property var buses: ({})
    function ddcWrite(bus: int, value: int, name: string): void {
        const b = buses[bus] ?? { target: value, running: false, fails: 0, name: name };
        b.target = value;
        b.name = name;
        buses[bus] = b;
        if (!b.running)
            startWrite(bus);
    }
    function startWrite(bus: int): void {
        const b = buses[bus];
        b.running = true;
        b.sent = b.target;
        const p = writer.createObject(root, { bus: bus, value: b.sent });
        p.running = true;
    }
    function writeDone(bus: int, ok: bool, proc: var): void {
        proc.destroy();
        const b = buses[bus];
        if (!b)
            return;
        b.fails = ok ? 0 : b.fails + 1;
        if (b.fails >= 3) {
            console.warn("Brightness: DDC/CI falla en el bus", bus, "→ atenuación por software");
            const mp = Object.assign({}, ddcMap);
            delete mp[b.name];
            ddcMap = mp;
            delete buses[bus];        // a later re-detection starts clean
            rebuild();
            return;
        }
        if (b.target !== b.sent)
            gap.createObject(root, { bus: bus });   // ≥ 200 ms between writes on the same bus
        else
            b.running = false;
    }
    // one short-lived timer per bus, so two monitors never steal each other's turn
    Component {
        id: gap
        Timer {
            id: t
            property int bus
            interval: 200
            running: true
            onTriggered: {
                root.startWrite(t.bus);
                t.destroy();
            }
        }
    }
    Component {
        id: writer
        Process {
            id: p
            property int bus
            property int value
            command: ["timeout", "5", "ddcutil", "--bus", String(bus), "--noverify", "setvcp", "10", String(value)]
            onExited: code => root.writeDone(p.bus, code === 0, p)
        }
    }

    FileView {
        id: stateFile
        atomicWrites: true
        path: Paths.brightness
        printErrors: false
        blockLoading: false
        preload: false
    }
}
