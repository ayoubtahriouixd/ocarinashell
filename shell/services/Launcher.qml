pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../modules/torii/fuzzy.js" as Fuzzy
import "../modules/settei/index.js" as SetteiIndex

// 鳥居 Torii — the launcher's brain (UI in modules/torii). Providers by prefix:
//   (none) apps + actions + settings + windows   = calculator (qalc)   > command   ? web   / files (fd)
//   @ windows   : kanji · emoji · kaomoji   ! settings pages   ~ SSH hosts   ; ask 蛇 Snake (fase 15)
// Apps are scored with fuzzy.js over name / generic name / keywords / executable, plus frecency (persisted).
// Async providers (qalc, fd) are debounced and the previous process is cancelled on every keystroke.
Singleton {
    id: root

    property bool open: false
    property string screen: ""          // output where it opens (niri's focused one)
    property string query: ""
    property string mode: "all"         // all | files | calc | kanji | settings | commands | windows | ssh | web | snake
    property int selected: 0
    property var results: []            // [{ group, title, html, subtitle, icon, iconImage, tint, badge, run, alt }]
    property double lastFilterMs: 0

    readonly property var modes: [
        { id: "all", label: "Todo", icon: "apps", prefix: "" },
        { id: "files", label: "Archivos", icon: "folder", prefix: "/" },
        { id: "calc", label: "Calcular", icon: "calculate", prefix: "=" },
        { id: "kanji", label: "Kanji y emoji", icon: "translate", prefix: ":" },
        { id: "settings", label: "Ajustes", icon: "tune", prefix: "!" },
        { id: "commands", label: "Comandos", icon: "terminal", prefix: ">" }
    ]
    readonly property var prefixes: ({ "/": "files", "=": "calc", ":": "kanji", "!": "settings", ">": "commands",
                                       "@": "windows", "~": "ssh", "?": "web", ";": "snake" })

    property double openedAt: 0
    property real lastOpenMs: 0
    // benchmark: average refresh time over n runs for query q (IPC launcher bench)
    function bench(q: string, n: int): string {
        n = Math.max(1, Math.min(500, n));      // the UI thread runs this: bounded
        const saved = query;
        query = q;
        const t0 = Date.now();
        for (let i = 0; i < n; i++)
            refresh();
        const avg = (Date.now() - t0) / n;
        const count = results.length;
        query = saved;
        return JSON.stringify({ query: q, runs: n, avgMs: avg, apps: apps.length, results: count });
    }
    function show(m: string, q: string): void {
        openedAt = Date.now();
        mode = m && m !== "undefined" ? m : "all";
        query = q && q !== "undefined" ? q : "";
        selected = 0;
        screen = Niri.focusedOutput;
        refresh();
        open = true;
    }
    function hide(): void {
        open = false;
        cancelAsync();
    }
    function toggle(): void {
        open ? hide() : show("all", "");
    }
    function cycleMode(dir: int): void {
        const i = modes.findIndex(m => m.id === mode);
        mode = modes[(i + dir + modes.length) % modes.length].id;
        selected = 0;
        refresh();
    }

    // ── data ─────────────────────────────────────────────────────────────────────────────────
    // apps (re-indexed when the desktop entries change)
    property var apps: []
    function indexApps(): void {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            const exe = (e.command && e.command.length > 0 ? e.command[0] : "").split("/").pop();
            out.push({ entry: e, id: e.id, name: e.name, nName: Fuzzy.norm(e.name),
                       generic: e.genericName ?? "", nGeneric: Fuzzy.norm(e.genericName),
                       nKeys: Fuzzy.norm((e.keywords ?? []).join(" ") + " " + (e.categories ?? []).join(" ")),
                       nExe: Fuzzy.norm(exe), icon: e.icon,
                       fune: (/^(winapps|fune)-/.test(e.id) && !/^fune-web-/.test(e.id)) || (e.categories ?? []).indexOf("X-Fune") >= 0,
                       actions: e.actions ?? [] });
        }
        apps = out;
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.indexApps(); }
    }

    // frecency: { id: { n, t } } — count and last use (days decay)
    property var frecency: ({})
    function frecencyBonus(id: string): real {
        const f = frecency[id];
        if (!f)
            return 0;
        const days = (Date.now() - f.t) / 86400000;
        return Math.min(60, 12 * Math.log(1 + f.n)) * Math.pow(0.5, days / 14);
    }
    function used(id: string): void {
        const f = Object.assign({}, frecency);
        const cur = f[id] ?? { n: 0, t: 0 };
        f[id] = { n: cur.n + 1, t: Date.now() };
        frecency = f;
        frecFile.setText(JSON.stringify(f) + "\n");
    }
    FileView {
        id: frecFile
        atomicWrites: true
        path: Paths.state + "/frecency.json"
        printErrors: false
        onLoaded: {
            try {
                root.frecency = JSON.parse(text());
            } catch (e) {}
        }
    }

    // system actions, always searchable in Spanish
    readonly property var actions: [
        { t: "Bloquear pantalla", k: "bloquear lock kagi", i: "lock", run: ["ocarina", "lock"] },
        { t: "Suspender", k: "suspender dormir sleep", i: "bedtime", run: ["systemctl", "suspend"] },
        { t: "Menú de energía", k: "apagar reiniciar cerrar sesion dengen power", i: "power_settings_new", run: ["ocarina", "power"] },
        { t: "Captura de región", k: "captura pantalla screenshot", i: "screenshot_region", run: ["niri", "msg", "action", "screenshot"] },
        { t: "Captura de pantalla completa", k: "captura pantalla screenshot", i: "screenshot_monitor", run: ["niri", "msg", "action", "screenshot-screen"] },
        { t: "Grabar pantalla", k: "grabar video record", i: "screen_record", run: ["ocarina", "record"] },
        { t: "Grabar una región", k: "grabar video record region", i: "crop_free", run: ["ocarina", "record", "region"] },
        { t: "Tema oscuro Kurenai", k: "tema oscuro kurenai theme dark", i: "dark_mode", run: [Paths.bin + "/ocarina-theme", "apply", "kurenai", "--quiet"] },
        { t: "Tema claro Kōhaku", k: "tema claro kohaku theme light", i: "light_mode", run: [Paths.bin + "/ocarina-theme", "apply", "kohaku", "--quiet"] },
        { t: "忍 Shinobi · ahorro extremo", k: "shinobi ahorro bateria", i: "battery_saver", run: ["ocarina", "shinobi", "toggle"] },
        { t: "鬼 Oni · rendimiento extremo", k: "oni rendimiento juego gaming", i: "bolt", run: ["ocarina", "oni", "toggle"] },
        { t: "船 Fune · apps de Windows", k: "windows fune vm", i: "sailing", run: ["ocarina", "fune"] },
        { t: "集中 Foco 25 minutos", k: "foco focus pomodoro concentrar", i: "timer", run: ["ocarina", "focus", "25"] },
        { t: "集中 Foco 50 minutos", k: "foco focus pomodoro concentrar", i: "timer", run: ["ocarina", "focus", "50"] },
        { t: "色 Cuentagotas", k: "color cuentagotas pick iro", i: "colorize", run: ["ocarina", "pick-color"] },
        { t: "読 Leer y traducir pantalla", k: "leer traducir ocr yomu", i: "translate", run: ["ocarina", "read", "--translate"] },
        { t: "No molestar", k: "no molestar dnd silencio", i: "do_not_disturb_on", run: ["ocarina", "notifications", "dnd", "toggle"] },
        { t: "Luz nocturna", k: "luz nocturna noche night", i: "nightlight", run: ["ocarina", "nightlight", "auto"] },
        { t: "Despierto · no suspender", k: "despierto cafeina caffeine", i: "coffee", run: ["ocarina", "caffeine"] },
        { t: "Centro de control", k: "engawa control", i: "tune", run: ["ocarina", "engawa"] },
        { t: "Notificaciones", k: "notificaciones fumi", i: "notifications", run: ["ocarina", "notifications"] },
        { t: "Calendario", k: "calendario koyomi", i: "calendar_month", run: ["ocarina", "koyomi"] },
        { t: "Portapapeles", k: "portapapeles kura clipboard", i: "content_paste", run: ["ocarina", "clipboard"] },
        { t: "Notas", k: "notas techo notes", i: "edit_note", run: ["ocarina", "notes"] },
        { t: "Monitor del sistema", k: "monitor procesos mihari tareas", i: "monitoring", run: ["ocarina", "tasks"] },
        { t: "Chuleta de atajos", k: "atajos chuleta teclas", i: "keyboard", run: ["ocarina", "cheatsheet"] },
        { t: "Renombrar espacio", k: "renombrar espacio workspace", i: "edit", run: ["ocarina", "rename-workspace"] },
        { t: "Crear regla de ventana", k: "regla ventana mado", i: "rule", run: ["ocarina", "rules"] },
        { t: "Siguiente fondo de pantalla", k: "fondo wallpaper kabegami", i: "wallpaper", run: ["ocarina", "wallpaper", "next"] }
    ]

    // kanji · emoji · kaomoji
    property var symbols: []            // [{ s, n (normalised words), label, kind }]
    property var kaomoji: []
    property bool emojiLoaded: false    // both emoji sources settled (loaded or missing)
    property int emojiPending: 2
    function emojiSettled(): void {
        if (--emojiPending === 0) {
            emojiLoaded = true;
            indexSymbols();
        }
    }
    function indexSymbols(): void {
        const out = [];
        // kaomoji (Spanish words)
        for (const k of (Settings.data.extras.kaomoji ? kaomoji : []))
            out.push({ s: k.k, n: Fuzzy.norm(k.es.join(" ") + " " + k.cat), label: k.es.join(", "), kind: "顔文字 kaomoji" });
        // kanji used by the UI (glossary) with their Spanish meaning
        const g = Glossary.g;
        const add = (kanji, es) => { if (kanji && es) out.push({ s: kanji, n: Fuzzy.norm(es + " " + kanji), label: es, kind: "漢字 kanji" }); };
        for (const key of ["modules", "toggles", "powerProfiles"])
            for (const id in (g[key] ?? {}))
                add(g[key][id].kanji, g[key][id].es);
        for (const arr of ["weekdays", "seasons", "moonPhases", "power", "settingsPages"])
            for (const e of (g[arr] ?? []))
                add(e.kanji, e.es);
        for (const m of (g.months ?? []))
            add(m.wafu, m.es);
        // emoji: Spanish names + keywords (assets/data/emoji-es.json, CLDR) in the order of Unicode's emoji-test.txt,
        // whose English name is searchable too; skin-tone variants are left out
        const es = emojiNames.loaded ? (JSON.parse(emojiNames.text()).names ?? {}) : {};
        const seen = {};
        const emoji = (s, line, en) => {
            const [name, words] = (line ?? "").split("|");
            out.push({ s: s, n: Fuzzy.norm([name, words, en].filter(x => x).join(" ")), label: name || en, kind: "emoji" });
        };
        const test = emojiTest.loaded ? emojiTest.text() : "";
        for (const line of test.split("\n")) {
            const m = /^[0-9A-F ]+;\s*fully-qualified\s*#\s*(\S+)\s+E[\d.]+\s+(.+)$/.exec(line);
            if (!m || /\u{1F3FB}|\u{1F3FC}|\u{1F3FD}|\u{1F3FE}|\u{1F3FF}/u.test(m[1]))
                continue;
            const key = m[1].replace(/\uFE0F/g, "");
            seen[key] = true;
            emoji(m[1], es[key], m[2]);
        }
        for (const key in es)
            if (!seen[key])
                emoji(key, es[key], "");
        symbols = out;
    }
    FileView {
        path: Paths.asset("data/kaomoji.json")
        onLoaded: {
            try {
                root.kaomoji = JSON.parse(text()).kaomoji;
            } catch (e) {}
        }
    }
    // both emoji files get their path on first use: a FileView loads (in the background) as soon as it has one
    FileView {
        id: emojiNames
        printErrors: false
        onLoaded: root.emojiSettled()
        onLoadFailed: root.emojiSettled()
    }
    FileView {
        id: emojiTest                   // package `unicode-emoji` (optional: without it, CLDR order and Spanish only)
        printErrors: false
        onLoaded: root.emojiSettled()
        onLoadFailed: root.emojiSettled()
    }
    function ensureSymbols(): void {
        if (emojiNames.path !== "")
            return;
        emojiNames.path = Paths.asset("data/emoji-es.json");
        emojiTest.path = "/usr/share/unicode/emoji/emoji-test.txt";
    }

    // async data arriving while open (symbols index, SSH hosts) refreshes the list
    onSymbolsChanged: if (open) refresh()
    onKaomojiChanged: if (emojiLoaded) indexSymbols()
    readonly property bool kaomojiOn: Settings.data.extras.kaomoji
    onKaomojiOnChanged: if (emojiLoaded) indexSymbols()

    // SSH hosts (Host names only) from ssh.configPath or ~/.ssh/config; re-read when the path changes
    property var sshHosts: []
    onSshHostsChanged: if (open) refresh()
    readonly property string sshConfig: Honban.sshConfig
    property bool sshRead: false
    onSshConfigChanged: sshRead = false
    Process {
        id: sshProc
        command: [Paths.bin + "/ocarina-ssh-hosts", root.sshConfig]
        stdout: StdioCollector {
            onStreamFinished: {
                const extra = Settings.data.ssh.prodHosts ?? [];
                root.sshRead = true;
                root.sshHosts = text.split("\n").filter(l => l !== "").map(l => {
                    const [h, p] = l.split("\t");
                    return { host: h, prod: p === "1" || extra.includes(h), n: Fuzzy.norm(h) };
                });
            }
        }
    }

    // ── async providers ──────────────────────────────────────────────────────────────────────
    property string calcResult: ""
    property string calcFor: ""
    property var files: []
    property string filesFor: ""
    function cancelAsync(): void {
        for (const p of [calc, fd])
            if (p.running) {
                p.stale = true;
                p.signal(15);
            }
    }
    Timer {
        id: asyncDelay
        interval: 120
        onTriggered: root.runAsync()
    }
    // A running search is killed and marked stale: its (partial) output is dropped and, once it has exited, the
    // latest query is launched (setting `running` on a process that is still alive would do nothing).
    function runAsync(): void {
        const q = parsed().q;
        const m = parsed().mode;
        const p = m === "calc" && q !== "" ? calc : m === "files" && q.length >= 2 ? fd : null;
        if (!p)
            return;
        if (p.running) {
            p.stale = true;
            p.signal(15);
            return;
        }
        p.stale = false;
        p.forQ = q;
        p.command = p === calc ? ["qalc", "-t", "-set", "decimal comma off", q]
            : ["fd", "--ignore-case", "--fixed-strings", "--max-results", "40", "--max-depth", "6", "--exclude", ".cache",
               "--exclude", "node_modules", "--", q, Paths.home || "/"];
        p.running = true;
    }
    function current(p: var): bool {
        return !p.stale && p.forQ === parsed().q;
    }
    Process {
        id: calc
        property string forQ: ""
        property bool stale: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.current(calc))
                    return;
                root.calcResult = text.trim();
                root.calcFor = calc.forQ;
                root.refresh();
            }
        }
        onExited: if (stale && root.open) root.runAsync()
    }
    Process {
        id: fd
        property string forQ: ""
        property bool stale: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.current(fd))
                    return;
                root.files = text.split("\n").filter(l => l !== "");
                root.filesFor = fd.forQ;
                root.refresh();
            }
        }
        onExited: if (stale && root.open) root.runAsync()
    }

    // ── search ───────────────────────────────────────────────────────────────────────────────
    function parsed(): var {
        const c = query.charAt(0);
        if (c in prefixes)
            return { mode: prefixes[c], q: query.slice(1).trim() };
        return { mode: mode, q: query.trim() };
    }

    onQueryChanged: {
        selected = 0;
        refresh();
        asyncDelay.restart();
    }

    function refresh(): void {
        const t0 = Date.now();
        const p = parsed();
        const q = p.q;
        const accent = Theme.colors.accent.toString();
        let out = [];
        // stable for equal scores (V4's sort is not): keeps the source order, e.g. ~/.ssh/config
        const take = (group, list, max) => {
            list.forEach((r, i) => r._i = i);
            list.sort((a, b) => b._s - a._s || a._i - b._i);
            for (const r of list.slice(0, max))
                out.push(Object.assign({ group: group }, r));
        };

        if (p.mode === "all" || p.mode === "commands" && q === "") {
            // apps
            const apps = [];
            for (const a of root.apps) {
                let best = null, field = "name";
                if (q === "") {
                    best = { score: 0, pos: [] };
                } else {
                    best = Fuzzy.score(q, a.nName, a.name);
                    const tries = [[a.nGeneric, a.generic, 0.7, false], [a.nKeys, "", 0.6, true], [a.nExe, "", 0.5, true]];
                    for (const [n, raw, w, words] of tries) {
                        const s = words ? Fuzzy.word(q, n) : Fuzzy.score(q, n, raw);
                        if (s && (!best || s.score * w > best.score)) {
                            best = { score: s.score * w, pos: [] };
                            field = "other";
                        }
                    }
                }
                if (!best)
                    continue;
                const fb = root.frecencyBonus(a.id);
                if (q === "" && fb === 0)
                    continue;            // empty query: only the apps you use
                apps.push({ _s: best.score + fb, title: a.name,
                            html: field === "name" ? Fuzzy.highlight(a.name, best.pos, accent) : Fuzzy.escapeHtml(a.name),
                            subtitle: (a.generic || "Aplicación") + (a.fune ? " · Windows (Fune)" : "") + (fb > 20 ? " · usada a menudo" : ""),
                            iconImage: a.icon, badge: a.fune ? "船" : "", kind: "app", ref: a });
                // desktop actions matching the query, as sub-results
                if (q !== "")
                    for (const act of a.actions) {
                        const s = Fuzzy.score(q, Fuzzy.norm(act.name), act.name);
                        if (s && s.score > 40)
                            apps.push({ _s: s.score * 0.6 + fb * 0.5 - 20, title: a.name + " → " + act.name,
                                        html: Fuzzy.escapeHtml(a.name) + " → " + Fuzzy.highlight(act.name, s.pos, accent),
                                        subtitle: "Acción de " + a.name, iconImage: act.icon || a.icon, kind: "action", ref: act, app: a });
                    }
            }
            take("Aplicaciones", apps, q === "" ? 6 : 8);
            if (q !== "") {
                const acts = [];
                for (const a of root.actions) {
                    const s = Fuzzy.score(q, Fuzzy.norm(a.t + " " + a.k), a.t + " " + a.k);
                    if (s && s.score > 30)
                        acts.push({ _s: s.score, title: a.t, html: Fuzzy.highlight(a.t, s.pos.filter(i => i < a.t.length), accent),
                                    subtitle: "Acción del sistema", icon: a.i, kind: "system", ref: a });
                }
                take("Acciones", acts, 4);
                const wins = searchWindows(q, accent);
                take("Ventanas", wins, 3);
                take("Ajustes", searchSettings(q, accent), 3);
            }
        } else if (p.mode === "windows") {
            take("Ventanas", searchWindows(q, accent), 20);
        } else if (p.mode === "settings") {
            take("Ajustes", searchSettings(q, accent), 20);
        } else if (p.mode === "calc") {
            if (q !== "") {
                const r = !Tools.has("qalc") ? "Falta qalc (paquete libqalculate)" : root.calcFor === q ? root.calcResult : "…";
                out.push({ group: "Calcular", title: r, html: Fuzzy.escapeHtml(r), subtitle: q + " · Intro copia el resultado",
                           icon: "calculate", kind: "calc", ref: r });
            }
        } else if (p.mode === "files") {
            const list = root.filesFor === q ? root.files : [];
            const home = Quickshell.env("HOME") ?? "";
            for (const f of list) {
                const name = f.replace(/\/$/, "").split("/").pop();
                const dir = f.replace(/\/$/, "").split("/").slice(0, -1).join("/").replace(home, "~");
                const isDir = f.endsWith("/");
                const s = Fuzzy.score(q, Fuzzy.norm(name), name);
                out.push({ group: "Archivos", title: name, html: Fuzzy.highlight(name, s ? s.pos : [], accent),
                           subtitle: dir + (isDir ? " · carpeta" : ""), icon: isDir ? "folder" : "draft",
                           tint: isDir ? "accent2" : "", kind: "file", ref: f });
            }
            if (!Tools.has("fd"))
                out.push({ group: "Archivos", title: "Falta fd", html: "Falta fd", subtitle: "Instálalo con pacman",
                           icon: "search_off", kind: "none" });
            else if (q.length < 2)
                out.push({ group: "Archivos", title: "Escribe al menos 2 letras", html: "Escribe al menos 2 letras",
                           subtitle: "Busca en tu carpeta personal", icon: "search", kind: "none" });
        } else if (p.mode === "commands") {
            out.push({ group: "Comando", title: q, html: Fuzzy.escapeHtml(q), subtitle: "Intro: en Ghostty · Ctrl+Intro: en segundo plano",
                       icon: "terminal", kind: "cmd", ref: q });
        } else if (p.mode === "snake") {
            const t = q === "" ? "Pregunta a Snake…" : q;
            out.push({ group: "蛇 Snake", title: t, html: Fuzzy.escapeHtml(t),
                       subtitle: q === "" ? "La IA local: escribe tu pregunta" : "Intro: preguntar a Snake (local, sin nube)",
                       glyph: "蛇", glyphKanji: true, kind: q === "" ? "none" : "snake", ref: q });
        } else if (p.mode === "web") {
            out.push({ group: "Web", title: q, html: Fuzzy.escapeHtml(q), subtitle: "Buscar en " + Settings.data.launcher.webEngine,
                       icon: "travel_explore", kind: "web", ref: q });
        } else if (p.mode === "kanji") {
            root.ensureSymbols();
            // ~2500 symbols: keep the best 30 while scanning (no full sort), build rows only for those
            const nq = Fuzzy.norm(q), best = [];
            for (const s of root.symbols) {
                const m = q === "" ? { score: 0 } : Fuzzy.word(nq, s.n, true);
                if (!m)
                    continue;
                const sc = m.score + (s.kind === "emoji" ? 0 : 8);
                if (best.length === 30 && sc <= best[29]._s)
                    continue;
                let k = Math.min(best.length, 29);
                while (k > 0 && best[k - 1]._s < sc)
                    k--;
                best.splice(k, 0, { _s: sc, sym: s });
                if (best.length > 30)
                    best.pop();
            }
            // emoji and single kanji go in the icon tile; kaomoji and kanji words in the title, next to the meaning
            take("Kanji, emoji y kaomoji", best.map(b => {
                const s = b.sym, tile = s.kind === "emoji" || !s.kind.startsWith("顔") && s.s.length <= 3;
                return { _s: b._s, title: s.s + "   " + s.label,
                         html: tile ? Fuzzy.escapeHtml(s.label) : Fuzzy.escapeHtml(s.s) + "   " + Fuzzy.escapeHtml(s.label),
                         subtitle: s.kind + " · Intro copia", icon: s.kind === "emoji" ? "" : s.kind.startsWith("顔") ? "mood" : "translate",
                         glyph: tile ? s.s : "", glyphKanji: tile && s.kind !== "emoji", kind: "symbol", ref: s.s };
            }), 30);
        } else if (p.mode === "ssh") {
            if (!Settings.data.ssh.enabled) {
                out.push({ group: "SSH", title: "SSH desactivado", html: "SSH desactivado", subtitle: "Actívalo en Ajustes",
                           icon: "lan", kind: "none" });
            } else if (!sshProc.running && !root.sshRead) {
                sshProc.running = true;
            }
            const list = [];
            for (const h of (Settings.data.ssh.enabled ? root.sshHosts : [])) {
                const m = q === "" ? { score: 0, pos: [] } : Fuzzy.score(q, h.n, h.host);
                if (m)
                    list.push({ _s: m.score, title: h.host, html: Fuzzy.highlight(h.host, m.pos, accent),
                                subtitle: h.prod ? "本番 · producción" : "SSH", icon: h.prod ? "dns" : "lan",
                                tint: h.prod ? "accent" : "", kind: "ssh", ref: h.host });
            }
            take("SSH", list, 30);
        }
        // keyboard numbers Ctrl+1…9 for the first nine
        out.forEach((r, i) => r.n = i < 9 ? i + 1 : 0);
        results = out;
        if (selected >= out.length)
            selected = Math.max(0, out.length - 1);
        lastFilterMs = Date.now() - t0;
    }

    function searchWindows(q: string, accent: string): var {
        const out = [];
        for (const id in Niri.windows) {
            const w = Niri.windows[id];
            const label = (w.title || "") + " — " + (w.app_id || "");
            const s = q === "" ? { score: 0, pos: [] } : Fuzzy.score(q, Fuzzy.norm(label), label);
            if (s)
                out.push({ _s: s.score, title: w.title || w.app_id, html: Fuzzy.highlight(w.title || w.app_id, s.pos.filter(i => i < (w.title || "").length), accent),
                           subtitle: "Ventana · " + (w.app_id || "") , icon: "select_window", kind: "window", ref: w.id });
        }
        return out;
    }
    function searchSettings(q: string, accent: string): var {
        const out = [];
        for (const pg of (Glossary.g.settingsPages ?? [])) {
            const s = q === "" ? { score: 0, pos: [] } : Fuzzy.score(q, Fuzzy.norm(pg.es + " " + pg.id + " " + (pg.keys ?? "")), pg.es + " " + pg.id + " " + (pg.keys ?? ""));
            if (s)
                out.push({ _s: s.score, title: pg.es, html: Fuzzy.highlight(pg.es, s.pos.filter(i => i < pg.es.length), accent),
                           subtitle: "Ajustes › " + pg.kanji, icon: "tune", kind: "setting", ref: pg.id });
        }
        // every row of Settei (generated index): opens the page and flashes the row. Contiguous word matches only
        // (a scattered fuzzy match over ~220 long rows cost ~11 ms per keystroke and was mostly noise), from 2 letters
        if (q.length >= 2) {
            const pages = Glossary.g.settingsPages ?? [];
            const nq = Fuzzy.norm(q);
            for (const e of SetteiIndex.entries) {
                if (e._n === undefined)
                    e._n = Fuzzy.norm(e.t + " " + (e.s ?? "") + " " + (e.k ?? ""));
                const s = Fuzzy.word(nq, e._n, true);
                if (!s)
                    continue;
                const pg = pages.find(p => p.id === e.p);
                out.push({ _s: s.score - 5, title: e.t, html: Fuzzy.highlight(e.t, s.pos.filter(i => i < e.t.length), accent),
                           subtitle: "Ajustes › " + (pg ? pg.es : e.p) + (e.s ? " · " + e.s : ""), icon: "tune", kind: "setting",
                           ref: e.p, row: e.t });
            }
        }
        return out;
    }

    // ── activation ───────────────────────────────────────────────────────────────────────────
    function activate(i: int, alt: bool): void {
        const r = results[i];
        if (!r || r.kind === "none")
            return;
        let keep = false;
        switch (r.kind) {
        case "app":
            used(r.ref.id);
            r.ref.entry.execute();
            break;
        case "action":
            used(r.app.id);
            r.ref.execute();
            break;
        case "system":
            Quickshell.execDetached(r.ref.run);
            break;
        case "window":
            Niri.focusWindow(r.ref);
            break;
        case "setting":
            if (r.row) {
                Settei.show("");
                Settei.goTo(r.ref, r.row);
            } else {
                Settei.show(r.ref);
            }
            break;
        case "calc":
        case "symbol":
            Quickshell.execDetached(["wl-copy", "--", r.ref]);
            Osd.show("info", 0, "Copiado: " + r.ref, "content_copy");
            break;
        case "file":
            Quickshell.execDetached(["xdg-open", r.ref]);
            break;
        case "cmd":
            if (alt)
                Quickshell.execDetached(["sh", "-c", r.ref]);
            else
                // the command goes as an argument, not spliced into the script: a trailing «&» or «#» cannot eat the exec
                Quickshell.execDetached(["ghostty", "+new-window", "-e", "sh", "-c", 'eval "$1"; exec "${SHELL:-fish}"', "sh", r.ref]);
            break;
        case "web": {
            const engines = { duckduckgo: "https://duckduckgo.com/?q=", google: "https://www.google.com/search?q=",
                              startpage: "https://www.startpage.com/do/search?q=" };
            Qt.openUrlExternally((engines[Settings.data.launcher.webEngine] ?? engines.duckduckgo) + encodeURIComponent(r.ref));
            break;
        }
        case "ssh":
            Quickshell.execDetached(["ocarina", "ssh", r.ref]);
            break;
        case "snake":
            Panels.show("snake", "");
            keep = !Snake.ask(r.ref);            // busy answering: Torii stays with the question
            break;
        }
        if (!keep)
            hide();
    }

    Component.onCompleted: indexApps()
}
