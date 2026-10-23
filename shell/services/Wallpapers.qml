pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 壁紙 Kabegami data: the wallpapers included with OcarinaShell + ~/Imágenes/Fondos (3 levels, wallhaven/ too),
// indexed by bin/ocarina-thumbs (480 px thumbnails cached by path+mtime, made in parallel in the background).
// Nothing runs until the browser opens (or rotation needs the list). Favourites and rotation live in Settings;
// rotation only on AC and outside Shinobi, with one long Timer. 季 seasonal rotation: wallpapers tagged 春夏秋冬,
// one of the current season's per 七十二候 kō (≈5 days), driven by Kisetsu's day tick, no timer at all.
Singleton {
    id: root

    readonly property string userDir: Paths.home + "/Imágenes/Fondos"
    property var items: []                 // [{ path, thumb, mtime, dir, builtin }]
    property bool indexing: indexer.running
    property bool indexed: false
    property real indexMs: 0
    // theme.json carries the theme wallpaper as an absolute path (older states: a bare file name)
    readonly property string themeWall: Theme.wallpaper === "" ? "" : Theme.wallpaper.startsWith("/") ? Theme.wallpaper : Paths.wallpapers + "/" + Theme.wallpaper
    readonly property string current: Settings.data.wallpaper.path || themeWall
    readonly property var favorites: Settings.data.wallpaper.favorites ?? []

    property var pending: []
    property double started: 0
    function refresh(): void {
        if (indexer.running)
            return;
        pending = [];
        started = Date.now();
        indexer.running = true;
    }
    // the browser calls this when it opens: with every thumbnail cached it takes ~40 ms and picks up new files
    function ensure(): void {
        refresh();
    }
    function isFavorite(p: string): bool {
        return favorites.indexOf(p) >= 0;
    }
    function toggleFavorite(p: string): void {
        const f = favorites.slice();
        const i = f.indexOf(p);
        if (i >= 0)
            f.splice(i, 1);
        else
            f.push(p);
        Settings.set("wallpaper.favorites", f);
    }
    function apply(p: string): void {
        // the theme's own wallpaper is stored as "" (it then follows theme changes)
        Settings.set("wallpaper.path", p === themeWall ? "" : p);
    }
    function themeFrom(p: string): void {
        apply(p);
        ThemeCtl.setAccent("wallpaper");
    }

    Process {
        id: indexer
        // niced: the first index of a big folder must not take the CPU (it runs in the background anyway)
        command: ["nice", "-n", "10", Paths.bin + "/ocarina-thumbs", Paths.wallpapers, root.userDir]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const o = JSON.parse(line);
                    o.builtin = o.dir === Paths.wallpapers;
                    root.pending.push(o);
                    // show what is cached at once, then batch the new thumbnails (no model reset per line)
                    if (!flush.running)
                        flush.start();
                } catch (e) {}
            }
        }
        onExited: {
            flush.stop();
            root.publish();
            root.indexed = true;
            root.indexMs = Date.now() - root.started;
        }
    }
    Timer {
        id: flush
        interval: 120
        onTriggered: root.publish()
    }
    function publish(): void {
        const seen = {};
        const list = pending.slice().filter(o => !seen[o.path] && (seen[o.path] = true));
        list.sort((a, b) => (b.builtin - a.builtin) || a.path.localeCompare(b.path));
        items = list;
    }
    // ── rotation (minutes; 0 = off): AC only, never in Shinobi ───────────────────────────────
    readonly property int rotateMin: Settings.data.wallpaper.rotate ?? 0
    readonly property bool rotating: rotateMin > 0 && !Power.onBattery && !Modes.quiet && !Lock.active
    Timer {
        interval: Math.max(1, root.rotateMin) * 60000
        repeat: true
        running: root.rotating
        onTriggered: root.next()
    }
    function next(): void {
        if (!indexed) {
            nextAfterIndex = true;
            refresh();
            return;
        }
        const pool = favorites.length >= 2 ? favorites : items.map(i => i.path);
        if (pool.length === 0)
            return;
        const i = pool.indexOf(current);
        apply(pool[(i + 1) % pool.length]);
    }
    property bool nextAfterIndex: false
    onIndexedChanged: {
        if (indexed && nextAfterIndex) {
            nextAfterIndex = false;
            next();
        }
        if (indexed && seasonalAfterIndex) {
            seasonalAfterIndex = false;
            applySeason();
        }
    }

    // ── 季 seasonal rotation ─────────────────────────────────────────────────────────────────
    readonly property var seasonTags: Settings.data.wallpaper.seasons ?? ({})
    readonly property bool seasonal: rotateMin === -1
    function seasonsOf(p: string): var {
        return seasonTags[p] ?? [];
    }
    function toggleSeason(p: string, s: int): void {
        const t = Object.assign({}, seasonTags);
        const l = (t[p] ?? []).slice();
        const i = l.indexOf(s);
        if (i >= 0)
            l.splice(i, 1);
        else
            l.push(s);
        l.sort();
        if (l.length > 0)
            t[p] = l;
        else
            delete t[p];
        Settings.set("wallpaper.seasons", t);
    }
    // only files that still exist (the index) and carry this season's tag
    function seasonPool(s: int): var {
        return items.map(i => i.path).filter(p => seasonsOf(p).indexOf(s) >= 0);
    }
    property bool seasonalAfterIndex: false
    function applySeason(): void {
        if (!seasonal || Kisetsu.season < 0 || Modes.quiet || Lock.active)
            return;
        if (!indexed) {
            seasonalAfterIndex = true;
            refresh();
            return;
        }
        const pool = seasonPool(Kisetsu.season);
        if (pool.length === 0)
            return;
        // the kō number walks the pool: each kō of the season shows the next tagged wallpaper
        const want = pool[(Kisetsu.ko.index ?? 0) % pool.length];
        if (want !== current)
            apply(want);
    }
    readonly property string seasonKey: seasonal + ":" + (Kisetsu.ko.index ?? -1) + ":" + Modes.quiet
    onSeasonKeyChanged: applySeason()
    Connections {
        target: Lock
        function onActiveChanged() {
            if (!Lock.active)
                root.applySeason();
        }
    }

    // ── 壁 Explorar: Wallhaven (public API, SFW only, no key) ──────────────────────────────────
    readonly property bool exploreOn: Settings.data.wallhaven.enabled && Tools.has("curl")
    property var wh: []                     // [{ id, full, thumb, res, ext }]
    property bool whBusy: whSearch.running
    property string whError: ""
    property int whPage: 1
    property string whQuery: ""
    readonly property string whDir: userDir + "/wallhaven"
    property var downloading: ({})
    function search(q: string, page: int): void {
        if (!exploreOn)
            return;
        whQuery = q;
        whPage = Math.max(1, page);
        whError = "";
        const params = "purity=100&categories=111&atleast=1920x1080&ratios=16x10,16x9&page=" + whPage
            + (q.trim() !== "" ? "&sorting=relevance&q=" + encodeURIComponent(q.trim()) : "&sorting=toplist&topRange=1M");
        whSearch.command = ["curl", "-fsS", "--max-time", "15", "-A", "OcarinaShell/" + Paths.version,
                            "https://wallhaven.cc/api/v1/search?" + params];
        whSearch.running = true;
    }
    Process {
        id: whSearch
        stdout: StdioCollector {
            id: whOut
        }
        onExited: code => {
            if (code !== 0) {
                root.whError = "No se pudo conectar con Wallhaven";
                return;
            }
            try {
                const d = JSON.parse(whOut.text).data ?? [];
                // purity is requested as SFW only; double-check every result anyway
                // only Wallhaven's own hosts are ever loaded (thumbnails in qs, originals by curl)
                const r = d.filter(x => x.purity === "sfw" && /^https:\/\/w\.wallhaven\.cc\//.test(x.path ?? "")
                                         && /^https:\/\/th\.wallhaven\.cc\//.test(x.thumbs?.large ?? ""))
                    .map(x => ({ id: x.id, full: x.path, thumb: x.thumbs.large, res: x.resolution,
                                 ext: (x.path.match(/\.(jpg|jpeg|png|webp)$/i) ?? ["", "jpg"])[1].toLowerCase() }));
                root.wh = root.whPage > 1 ? root.wh.concat(r) : r;
            } catch (e) {
                root.whError = "Respuesta de Wallhaven no válida";
            }
        }
    }
    function download(item: var, andApply: bool): void {
        if (!/^[a-z0-9]+$/i.test(item.id) || !/^https:\/\/w\.wallhaven\.cc\//.test(item.full) || downloading[item.id])
            return;
        const dest = whDir + "/wallhaven-" + item.id + "." + item.ext;
        const d = Object.assign({}, downloading);
        d[item.id] = true;
        downloading = d;
        const p = dlComp.createObject(root, { dest: dest, itemId: item.id, andApply: andApply });
        p.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && curl -fsSL --max-time 120 --max-filesize 62914560 -o "$2.part" "$1" && mv -f "$2.part" "$2"',
                     "sh", item.full, dest];
        p.running = true;
    }
    Component {
        id: dlComp
        Process {
            property string dest
            property string itemId
            property bool andApply
            onExited: code => {
                const d = Object.assign({}, root.downloading);
                delete d[itemId];
                root.downloading = d;
                if (code === 0) {
                    if (andApply)
                        root.apply(dest);
                    root.refresh();
                } else {
                    root.whError = "No se pudo descargar el fondo";
                }
                destroy();
            }
        }
    }
}
