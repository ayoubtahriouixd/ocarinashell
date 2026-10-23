pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User settings: ~/.config/ocarinashell/settings.json (docs/01-ARQUITECTURA §8, docs/06 capa 3.6).
// - Read as text and parsed here (not JsonAdapter): a corrupt file is detected, copied to settings.json.roto-<date>
//   and replaced by defaults instead of being silently overwritten.
// - Defaults are deep-merged under the user's file: unknown keys are kept, missing keys are added.
// - `version` + migrate(): one step per schema bump; `limits` keeps numbers in range. Writes are atomic.
// - Read with Settings.data.<section>.<key> (whole object is replaced on change, so bindings update);
//   write with Settings.set("section.key", value).
Singleton {
    id: root

    readonly property int schemaVersion: 5
    property var data: defaults()
    property bool ready: false
    property string lastError: ""

    signal corrupted(string backupPath)   // shell.qml shows it (config cannot depend on services)

    function defaults(): var {
        return {
            version: schemaVersion,
            appearance: {
                theme: "kurenai", accent: null, autoTheme: { enabled: false, day: "kohaku", night: "kurenai" },
                blur: true, transparency: true, animSpeed: 1.0, radius: 1.0, kanjiDecor: true, screenCorners: false,
                uiFont: "Geist", jpFont: "Zen Kaku Gothic New", displayFont: "Shippori Mincho B1", fontScale: 1.0,
                reducedMotion: false
            },
            // position: only "top" (Ayoub, fase 07). style: isles (mockup 15) | floating | attached | minimal (auto-hide)
            // showUsage: live CPU · GPU · RAM rings (with the %) next to the power profile (Ayoub, fase 14)
            bar: { position: "top", style: "isles", clock24: true, showSeconds: false, showWeather: false, showUsage: true,
                   showKisetsu: true, modules: ["workspaces", "title", "tray", "indicators", "cluster", "bell"] },
            island: { media: true, osd: true, notifPeek: true, recording: true, hover: true, wheelVolume: true,
                      swipeTracks: true, aura: true, hoverFx: true },
            display: {
                nightLight: { mode: "off", temp: 4000, from: "20:30", to: "07:00" },
                brightness: { keysTarget: "focused", ddc: true, softFallback: true, timeCurve: false, perOutput: {} },
                profiles: {}, autoProfile: true, notifyOnConnect: true, mirrorDnd: true, lidCloseToExternal: true,
                mirrorBefore: null
            },
            oled: { pixelShift: true, dimStatic: true, lockDrift: true },
            focus: { minutes: 50, breakMinutes: 10, dnd: true },
            session: { restore: "ask", exclude: [] },
            // minutes, 0 = never (fractions allowed: short values for tests)
            idle: { ac: { dim: 4, lock: 5, screenOff: 6, suspend: 0 },
                    battery: { dim: 2, lock: 3, screenOff: 4, suspend: 15 } },
            audio: { uiSounds: true, uiVolume: 0.6 },
            // autoShinobiAsk: at autoShinobiAt % ask first (Activar / Ahora no) instead of entering by itself
            power: { chargeLimit: { enabled: true, start: 75, end: 80 }, lowBattery: 15, autoShinobiAt: 10,
                     autoShinobiAsk: true, exitShinobiOnAC: true },
            notifications: { dnd: false, dndSchedule: null, timeout: 6, position: "top-right", privacyOnLock: true,
                             perApp: {} },
            // terminal (phase 8): Ghostty ink cursor (only on AC, outside Shinobi), fish greeting, daily fastfetch
            // opacity: Ghostty's background (and Neovim's, which follows it); 1 in Shinobi/Oni or without transparency
            terminal: { inkCursor: true, greeting: true, fastfetchDaily: true, opacity: 0.8 },
            // your Bluetooth on/off, applied again at every login (services/Bt): the rfkill state alone did not
            // survive a reboot (systemd-rfkill missed the save at shutdown and BlueZ powers controllers on)
            bluetooth: { enabled: true },
            // 広場 Hiroba (the island opened): anime touches and which sections it shows
            hiroba: { anime: true, speedLines: true, petals: true, vinyl: true, screentone: true,
                      sections: { me: true, clock: true, neko: true, month: true, season: true, music: true, system: true } },
            // 蛇 Snake (fase 15, docs/SNAKE.md): local AI loaded on demand; bin/ocarina-snake reads the same keys
            snake: { enabled: true, backend: "vulkan", model: "", fastModel: "", keepAliveMin: 5, ctx: 16384,
                     batteryAssistant: true, voiceLang: "es" },
            // 守 Mamori (fase 16, docs/06 capa 6): the autopilot; bin/ocarina-mamori reads the same keys.
            // ai snake|claude|both|off · batteryMin 0 = only on AC · firmware approve|off (BIOS/EC always with one touch)
            mamori: { enabled: true, ai: "snake", batteryMin: 0, maturationDays: 3, maturationDaysNoAi: 7, aur: true,
                      firmware: "approve", nightlyReboot: false, autoImprove: false, notify: true,
                      claudeBudget: { turns: 25, minutes: 15 },
                      seenAt: 0 },          // when you last left Ajustes › 守: what came before no longer counts as new
            // 広場 Hiroba: the hanko of your profile («» = first letter of your name; ~/.face wins if it exists)
            profile: { kanji: "" },
            lock: { fingerprint: true, showMedia: true, blurWallpaper: true },
            // niri input/layout written to state/niri/overrides.kdl by Settei (only owner)
            input: { layouts: ["es"], switchKeys: "alt_shift", repeatDelay: 260, repeatRate: 40,
                     touchpad: { tap: true, naturalScroll: true, dwt: true, speed: 0.25, scrollFactor: 1.0 },
                     trackpointSpeed: 0.2, mouseSpeed: 0.0, ffm: true, ffmScroll: "25", warpMouse: true, touch: true },
            windows: { gaps: 12, focusRing: true, focusRingWidth: 2, defaultWidth: 0.5, niriAnimations: true },
            // 忍 Shinobi (phase 10). brightnessCapExternal 100 = no ceiling (meant for USB-C monitors fed by the
            // laptop). pauseServices: user units stopped while the mode is on and started again after.
            shinobi: { refresh60: false, vrr: true, boostOff: true, bluetoothOff: true, bluetoothKeepAudio: true, brightnessCap: 35,
                       brightnessCapExternal: 100, kbdLightOff: true, wifiPowersave: true, pauseServices: [],
                       gpuLow: true, funeStop: true },
            // 鬼 Oni (phase 11, D-060). batteryAuto: what GameMode does unplugged — "ask" · "never" · "allow".
            // gpuLevel auto: «high» measured no faster (docs/JUEGOS.md). gpuFirst: no CPU turbo, so the shared power
            // budget goes to the GPU (+9 % in GPU-bound loads, worse in CPU-bound games). pauseServices: user units
            // stopped while the mode is on. gamescopePreset: the template of «Copiar opciones de Steam».
            oni: { auto: true, batteryAuto: "ask", exitBatteryAt: 20, gpuLevel: "auto", scx: true, gpuFirst: false,
                   fanMax: false, kishin: false, vrrGames: true, dnd: true, wifiNoPs: true, nightLightPause: false,
                   pauseServices: ["ocarina-cliphist-img.service"], gamescopePreset: "fsr", funePause: true },
            // 滑 Nameraka (phase 11 B, D-061). mode x2|x4|x6|custom («A medida», default: its target fps, 0 = the Hz).
            // flow 0 = from the calibration; perf auto|on|off. battery eco|normal|off. exclude: app-ids never touched.
            nameraka: { mode: "custom", fps: 0, engine: "auto", flow: 0, perf: "auto", battery: "eco", avSync: false,
                        auto: false, exclude: [] },
            // 船 Fune (phase 12, D-062). pauseMinutes: without Windows windows → pause (0 % CPU, RAM kept);
            // stopMinutes: paused that long → shut down (RAM freed; 0 = never). startOnAC: boot at login on AC.
            fune: { autoPause: true, pauseMinutes: 10, stopMinutes: 30, startOnAC: false, microphone: true },
            weather: { enabled: true, lat: 33.5731, lon: -7.5898, place: "Casablanca", units: "metric" },
            launcher: { frecency: true, webEngine: "duckduckgo", pinned: [] },     // pinned: app ids first in the ocarina drawer
            ssh: { enabled: true, configPath: "", prodHosts: [] },
            clipboard: { dbPath: "", maskSecrets: true, pasteOnEnter: false },
            techo: { mincho: false },
            // rotate: minutes between wallpapers (0 = off; only on AC; -1 = with the 七十二候, one per kō).
            // favorites: absolute paths · seasons: { path: [0–3] } (春 夏 秋 冬) for the seasonal rotation
            wallpaper: { path: "", perTheme: true, rotate: 0, favorites: [], seasons: {} },
            wallhaven: { enabled: true, query: "", purity: "sfw" },
            extras: { touchGestures: true, iro: true, yomu: true, kaomoji: true, wifiQr: true, vpnTile: true,
                      worldClocks: [] }
        };
    }

    // Each step takes the object at version N and returns it at N+1.
    function migrate(obj: var): var {
        if (typeof obj.version === "string" && /^[0-9]+$/.test(obj.version))
            obj.version = Number(obj.version);       // "3" typed by hand: not a reason to replay every migration
        if (typeof obj.version !== "number" || !Number.isInteger(obj.version) || obj.version < 1)
            obj.version = 1;
        // 1 → 2 (fase 07, D-046): appearance.animSpeed was a duration multiplier, now it is a speed
        if (obj.version === 1) {
            const a = obj.appearance;
            if (isPlainObject(a) && typeof a.animSpeed === "number" && a.animSpeed > 0 && a.animSpeed !== 1)
                a.animSpeed = Math.round(Math.max(0.5, Math.min(2, 1 / a.animSpeed)) * 4) / 4;
            obj.version = 2;
        }
        // 2 → 3 (fase 10, D-059): Shinobi defaults chosen with Ayoub; values he never touched move to the new ones
        if (obj.version === 2) {
            const sh = obj.shinobi;
            if (isPlainObject(sh)) {
                if (sh.brightnessCap === 40)
                    sh.brightnessCap = 35;
                if (sh.brightnessCapExternal === 30)
                    sh.brightnessCapExternal = 100;
                if (sh.bluetoothOff === false)
                    sh.bluetoothOff = true;
                sh.gpuLow = true;          // measured: −0,2 W in Shinobi (docs/ENERGIA.md)
            }
            obj.version = 3;
        }
        // 3 → 4 (fase 11, D-060): Oni's defaults decided by measuring; values Ayoub never touched move to the new ones
        if (obj.version === 3) {
            const o = obj.oni;
            if (isPlainObject(o)) {
                if (o.gpuLevel === "high" || o.gpuLevel === "max")
                    o.gpuLevel = o.gpuLevel === "max" ? "high" : "auto";
                if (typeof o.onBattery === "boolean")
                    o.batteryAuto = o.onBattery ? "allow" : "ask";
                delete o.onBattery;
                if (o.gamescopePreset === "auto")
                    o.gamescopePreset = "fsr";
                if (o.funePause === false)
                    o.funePause = true;
            }
            obj.version = 4;
        }
        // 4 → 5 (fase 15, D-079): Shinobi uses VRR instead of 60 Hz; the old default refresh60 would still blink black
        if (obj.version === 4) {
            if (isPlainObject(obj.shinobi) && obj.shinobi.refresh60 === true)
                obj.shinobi.refresh60 = false;
            obj.version = 5;
        }
        return obj;
    }

    function isPlainObject(v: var): bool {
        return v !== null && typeof v === "object" && !Array.isArray(v);
    }

    // defaults ⊕ user: user values win when they have the right type, unknown user keys survive, missing keys come
    // from defaults. A value of the wrong type (e.g. "display": null, "oled": 5) falls back to the default.
    function merge(def: var, user: var, path: string): var {
        if (user === undefined)
            return def;
        if (isPlainObject(def)) {
            if (!isPlainObject(user)) {
                console.warn("Settings: tipo no válido en", path || "(raíz)", "→ valor por defecto");
                return def;
            }
            const out = {};
            for (const k in user)
                out[k] = user[k];
            for (const k in def)
                out[k] = merge(def[k], user[k], path ? path + "." + k : k);
            return out;
        }
        if (def !== null && user !== null && typeof def !== typeof user) {
            console.warn("Settings: tipo no válido en", path, "→ valor por defecto");
            return def;
        }
        if (Array.isArray(def) !== Array.isArray(user) && def !== null) {
            console.warn("Settings: tipo no válido en", path, "→ valor por defecto");
            return def;
        }
        const lim = limits[path];
        if (lim !== undefined && user !== null && !withinLimits(lim, user)) {
            console.warn("Settings: valor fuera de rango en", path, "(" + JSON.stringify(user) + ") → valor por defecto");
            return def;
        }
        return user;
    }

    // Ranges and choices of the values a typo could make absurd: [min, max] for numbers, a list for strings.
    // Out of range → the default for that key only (the rest of the file is kept).
    readonly property var limits: {
        const l = {
            "appearance.animSpeed": [0.25, 4], "appearance.radius": [0, 2], "appearance.fontScale": [0.75, 1.5],
            "bar.position": ["top"], "bar.style": ["isles", "floating", "attached", "minimal"],
            "display.nightLight.temp": [1000, 6500],
            "focus.minutes": [1, 600], "focus.breakMinutes": [0, 120],
            "audio.uiVolume": [0, 1],
            "power.chargeLimit.start": [40, 95], "power.chargeLimit.end": [50, 100], "power.lowBattery": [1, 50],
            "power.autoShinobiAt": [0, 50],
            "notifications.timeout": [2, 60],
            "input.repeatDelay": [100, 2000], "input.repeatRate": [1, 100], "input.touchpad.speed": [-1, 1],
            "input.trackpointSpeed": [-1, 1], "input.mouseSpeed": [-1, 1],
            "windows.gaps": [0, 64], "windows.focusRingWidth": [0, 16], "windows.defaultWidth": [0.1, 1],
            "shinobi.brightnessCap": [5, 100], "shinobi.brightnessCapExternal": [0, 100],
            "oni.batteryAuto": ["ask", "never", "allow"], "oni.exitBatteryAt": [0, 100],
            "nameraka.mode": ["x2", "x4", "x6", "custom"], "nameraka.fps": [0, 240], "nameraka.perf": ["auto", "on", "off"],
            "nameraka.battery": ["eco", "normal", "off"],
            "fune.pauseMinutes": [0, 1440], "fune.stopMinutes": [0, 1440],
            "input.ffmScroll": ["visible", "25", "always"],
            "mamori.ai": ["snake", "claude", "both", "off"], "mamori.batteryMin": [0, 100],
            "mamori.maturationDays": [0, 30], "mamori.maturationDaysNoAi": [0, 30], "mamori.firmware": ["approve", "off"],
            "mamori.claudeBudget.turns": [3, 80], "mamori.claudeBudget.minutes": [2, 60],
            "snake.backend": ["vulkan", "npu"], "snake.keepAliveMin": [1, 120], "snake.ctx": [4096, 131072],
            "weather.lat": [-90, 90], "weather.lon": [-180, 180], "weather.units": ["metric", "imperial"]
        };
        for (const src of ["ac", "battery"])
            for (const k of ["dim", "lock", "screenOff", "suspend"])
                l["idle." + src + "." + k] = [0, 1440];
        return l;
    }
    function withinLimits(lim: var, v: var): bool {
        if (typeof lim[0] === "number")
            return typeof v === "number" && isFinite(v) && v >= lim[0] && v <= lim[1];
        return lim.indexOf(v) >= 0;
    }

    readonly property var forbidden: ["__proto__", "constructor", "prototype"]
    function get(path: string, fallback: var): var {
        let v = data;
        for (const part of path.split(".")) {
            if (forbidden.indexOf(part) >= 0)
                return fallback;
            if (!isPlainObject(v) || !(part in v))
                return fallback;
            v = v[part];
        }
        return v;
    }

    function set(path: string, value: var): void {
        const parts = path.split(".");
        if (parts.some(x => forbidden.indexOf(x) >= 0 || x === ""))
            return;
        const copy = JSON.parse(JSON.stringify(data));
        let o = copy;
        for (let i = 0; i < parts.length - 1; i++) {
            if (!isPlainObject(o[parts[i]]))
                o[parts[i]] = {};
            o = o[parts[i]];
        }
        o[parts[parts.length - 1]] = value;
        data = copy;
        save();
    }

    // Restablecer sección: puts the defaults back under `path` (e.g. "appearance", "display.brightness").
    function reset(path: string): void {
        let v = defaults();
        for (const part of path.split("."))
            v = isPlainObject(v) ? v[part] : undefined;
        if (v !== undefined)
            set(path, v);
    }
    function defaultOf(path: string): var {
        let v = defaults();
        for (const part of path.split("."))
            v = isPlainObject(v) ? v[part] : undefined;
        return v;
    }
    // Import (Settei): an already-parsed object goes through the same migrate + merge as the file on disk
    function replaceAll(obj: var): bool {
        if (!isPlainObject(obj))
            return false;
        data = merge(defaults(), migrate(obj), "");
        save();
        return true;
    }

    // writes are coalesced (150 ms): a burst of changes (arrow keys, a drag) is one write; flushed on exit
    property bool writeBlocked: false     // a corrupt file not yet copied aside: never overwrite it
    property bool keptLive: false         // corruption found while running: the in-memory settings were kept
    function save(): void {
        if (writeBlocked)
            return;
        if (!ready) {
            dirty = true;     // written once the file has been read (never overwrite it blindly at startup)
            return;
        }
        writeLater.restart();
    }
    function flush(): void {
        if (writeLater.running && !writeBlocked) {
            writeLater.stop();
            file.setText(JSON.stringify(data, null, 2) + "\n");
        }
    }
    Timer {
        id: writeLater
        interval: 150
        onTriggered: file.setText(JSON.stringify(root.data, null, 2) + "\n")
    }
    Component.onDestruction: flush()
    Connections {
        target: Qt.application
        function onAboutToQuit() { root.flush(); }
    }
    property bool dirty: false
    onReadyChanged: if (ready && dirty) { dirty = false; save(); }

    // A failed parse on a watcher reload is usually transient (an editor truncating and rewriting, a typo being
    // fixed): keep the good data in memory, retry, never write. Corruption is declared only on the first load or
    // after 3 failures in a row with the file stable.
    property int badReads: 0

    function ingest(txt: string): void {
        let obj = null;
        if (txt.trim() !== "") {
            try {
                obj = JSON.parse(txt);
            } catch (e) {
                lastError = String(e);
            }
        } else {
            lastError = "fichero vacío";
        }
        if (!isPlainObject(obj)) {
            badReads++;
            if (ready && badReads < 3) {
                retry.restart();
                return;
            }
            const bak = Paths.settings + ".roto-" + new Date().toISOString().replace(/[:.]/g, "-");
            console.warn("Settings: settings.json corrupto, copia en", bak, lastError);
            // nothing is written until the copy exists (save() respects it); at first load the defaults take over,
            // later the last good settings stay in memory and are written back over the broken file
            writeBlocked = true;
            keptLive = ready;
            if (!ready)
                data = defaults();
            backup.command = ["cp", "-f", Paths.settings, bak];
            backup.bak = bak;
            backup.running = true;
            return;
        }
        badReads = 0;
        writeBlocked = false;      // a good file again (fixed by hand): writes resume
        const before = JSON.stringify(obj);
        const merged = merge(defaults(), migrate(obj), "");
        if (JSON.stringify(merged) !== JSON.stringify(data))
            data = merged;
        ready = true;
        if (JSON.stringify(merged) !== before)
            save();   // new defaults, a migration or a type fix: persist once
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: file.reload()
    }
    Timer {
        id: retry
        interval: 700
        onTriggered: file.reload()
    }

    FileView {
        id: file
        path: Paths.settings
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
        onLoaded: root.ingest(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.data = root.defaults();
                root.ready = true;
                root.save();
            } else {
                root.lastError = FileViewError.toString(err);
                console.warn("Settings: no se pudo leer", Paths.settings, root.lastError);
            }
        }
    }

    // After the corrupt copy exists, write the settings in memory (defaults, or the last good ones) over the broken
    // file. If the copy fails nothing is ever written in this session: the broken file stays for Ayoub to look at.
    Process {
        id: backup
        property string bak: ""
        onExited: (code, status) => {
            root.ready = true;
            if (code === 0) {
                root.writeBlocked = false;
                root.badReads = 0;
                root.save();
                root.corrupted(bak);
            } else {
                console.warn("Settings: no se pudo copiar el fichero corrupto; no se sobrescribe en esta sesión");
                root.corrupted("");
            }
        }
    }
}
