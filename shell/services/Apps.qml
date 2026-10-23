pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import "../modules/torii/fuzzy.js" as Fuzzy

// 器 Utsuwa — the data behind the ocarina's app drawer (modules/obi/AppDrawer). One source of truth with Torii: the
// app index, the fuzzy scorer and the frecency all come from Launcher; this only adds categories, the frequent row,
// pinned apps (Settings › launcher.pinned) and the drawer's query. Pure functions of their inputs: no timers, no
// process, nothing runs while the drawer is closed.
Singleton {
    id: root

    // freedesktop main/additional categories → the drawer's rail (first match wins; order matters)
    readonly property var categories: [
        { id: "all", kanji: "全", label: "Todo" },
        { id: "recent", kanji: "近", label: "Frecuentes" },
        { id: "web", kanji: "網", label: "Internet", match: ["WebBrowser", "Network", "Email", "Chat", "InstantMessaging"] },
        { id: "dev", kanji: "創", label: "Desarrollo", match: ["Development", "IDE", "TextEditor", "TerminalEmulator"] },
        { id: "media", kanji: "映", label: "Multimedia", match: ["AudioVideo", "Audio", "Video", "Graphics", "Photography"] },
        { id: "office", kanji: "文", label: "Oficina", match: ["Office", "Education", "Science", "Viewer"] },
        { id: "games", kanji: "遊", label: "Juegos", match: ["Game"] },
        { id: "windows", kanji: "船", label: "Windows" },
        { id: "system", kanji: "機", label: "Sistema", match: ["System", "Settings", "Utility", "Monitor", "Security", "FileManager"] }
    ]

    function categoryOf(a: var): string {
        if (a.fune)
            return "windows";
        const cats = a.entry.categories ?? [];
        for (const c of categories)
            if (c.match && c.match.some(m => cats.indexOf(m) >= 0))
                return c.id;
        return "system";
    }

    // every visible app, A→Z (locale-aware, accents ignored), with its category
    readonly property var all: Launcher.apps.filter(a => !a.entry.noDisplay)
        .map(a => Object.assign({ cat: categoryOf(a) }, a))
        .sort((x, y) => x.name.localeCompare(y.name, "es", { sensitivity: "base" }))
    readonly property var counts: {
        const n = {};
        for (const a of all)
            n[a.cat] = (n[a.cat] ?? 0) + 1;
        n.all = all.length;
        n.recent = frequent.length;
        return n;
    }

    // pinned first (in the order you pinned them), then the most used (Launcher's frecency), up to 6
    readonly property var pinned: Settings.data.launcher.pinned ?? []
    readonly property var frequent: {
        const byId = {};
        for (const a of all)
            byId[a.id] = a;
        const out = pinned.map(id => byId[id]).filter(a => a !== undefined);
        const rest = all.filter(a => pinned.indexOf(a.id) < 0 && Launcher.frecencyBonus(a.id) > 0)
            .sort((x, y) => Launcher.frecencyBonus(y.id) - Launcher.frecencyBonus(x.id));
        return out.concat(rest).slice(0, 6);
    }
    function isPinned(id: string): bool {
        return pinned.indexOf(id) >= 0;
    }
    function togglePin(id: string): void {
        const p = pinned.slice();
        const i = p.indexOf(id);
        if (i >= 0)
            p.splice(i, 1);
        else
            p.unshift(id);
        Settings.set("launcher.pinned", p.slice(0, 12));
    }

    // the drawer's list for a query and a category → [{ app, html }] (html: name with the matched letters in red)
    function results(query: string, cat: string, accent: string): var {
        const q = Fuzzy.norm(query);
        const pool = cat === "recent" ? frequent : cat === "all" || q !== "" ? all : all.filter(a => a.cat === cat);
        if (q === "")
            return pool.map(a => ({ app: a, html: Fuzzy.escapeHtml(a.name) }));
        const out = [];
        for (const a of pool) {
            let best = Fuzzy.score(q, a.nName, a.name);
            let html = best ? Fuzzy.highlight(a.name, best.pos, accent) : Fuzzy.escapeHtml(a.name);
            for (const [n, raw, w, words] of [[a.nGeneric, a.generic, 0.7, false], [a.nKeys, "", 0.6, true], [a.nExe, "", 0.5, true]]) {
                const s = words ? Fuzzy.word(q, n) : Fuzzy.score(q, n, raw);
                if (s && (!best || s.score * w > best.score)) {
                    best = { score: s.score * w, pos: [] };
                    html = Fuzzy.escapeHtml(a.name);
                }
            }
            if (best)
                out.push({ app: a, html: html, s: best.score + Launcher.frecencyBonus(a.id) });
        }
        return out.sort((x, y) => y.s - x.s);
    }

    // `ocarina apps` / IPC `apps toggle`: the bar of the focused screen plays its ocarina and opens the drawer
    signal toggleRequested(string screen)
    function toggle(): void {
        toggleRequested(Niri.focusedOutput);
    }

    function launch(a: var): void {
        Launcher.used(a.id);
        a.entry.execute();
    }
    function runAction(a: var, act: var): void {
        Launcher.used(a.id);
        act.execute();
    }
}
