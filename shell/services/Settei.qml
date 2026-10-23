pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 設定 Settei — state of the settings window (modules/settei). Pages (order, glyph, header kanji) come from
// assets/data/kanji-ui.json → settingsPages, the same source the mockups are generated from. Deep links:
// `ocarina settings energia` → open("energia"). The window itself is a FloatingWindow loaded only while open.
Singleton {
    id: root

    property bool open: false
    property string page: "apariencia"
    property string query: ""
    property var pages: []
    // pages whose module arrives in a later phase: the slot is kept in the navigation (phase number shown)
    readonly property var later: ({})
    // search result to reveal once its page is loaded (SRow with the same title flashes and scrolls into view)
    property string highlight: ""
    signal reveal(string title)
    property Item flick: null          // the page Flickable (set by the window) for reveal()
    property int windowId: -1          // niri id of our window, to focus it instead of opening a second one

    readonly property var pageInfo: pages.find(p => p.id === page) ?? { id: page, kanji: "", glyph: "", es: page }

    function aliasOf(id: string): string {
        const a = { appearance: "apariencia", display: "pantalla", pantallas: "pantalla", haichi: "pantalla",
                    bar: "barra", sound: "sonido", audio: "sonido", network: "red", wifi: "red", bluetooth: "red",
                    power: "energia", "energía": "energia", battery: "energia", lock: "bloqueo", input: "entrada",
                    teclado: "entrada", keyboard: "entrada", notifications: "notificaciones", windows: "ventanas",
                    mado: "ventanas", wallpaper: "fondos", kabegami: "fondos", wallpapers: "fondos", about: "acerca",
                    shortcuts: "atajos", keys: "atajos", fluido: "nameraka", maintenance: "mamori",
                    mantenimiento: "mamori" };
        const k = (id ?? "").toLowerCase().trim();
        return a[k] ?? k;
    }
    function valid(id: string): bool {
        return pages.length === 0 || pages.some(p => p.id === id);
    }
    function show(id: string): void {
        const p = aliasOf(id);
        if (p !== "" && p !== "undefined" && valid(p))
            page = p;
        query = "";
        if (open)
            focusWindow();
        open = true;
    }
    // toggle: closed → open; open and focused → close; open behind other windows → bring it to the front
    function toggle(): void {
        if (!open) {
            open = true;
            return;
        }
        const w = Niri.windows[windowId];
        if (w && !w.is_focused)
            focusWindow();
        else
            open = false;
    }
    function close(): void {
        open = false;
    }
    function focusWindow(): void {
        if (windowId >= 0)
            Niri.focusWindow(windowId);
    }
    function go(id: string): void {
        if (valid(id))
            page = id;
    }
    function step(d: int): void {
        const i = pages.findIndex(p => p.id === page);
        const n = pages[(i + d + pages.length) % pages.length];
        if (n)
            page = n.id;
    }
    function goTo(id: string, title: string): void {
        query = "";
        if (page === id) {
            reveal(title);
            return;
        }
        highlight = title;
        page = id;
    }

    // find our own toplevel among niri's windows (title set by SetteiWindow)
    readonly property string windowTitle: "Ajustes de OcarinaShell"
    Connections {
        target: Niri
        function onWindowOpened(w) {
            if ((w.title ?? "") === root.windowTitle)
                root.windowId = w.id;
        }
    }
    onOpenChanged: if (!open) windowId = -1

    FileView {
        path: Paths.asset("data/kanji-ui.json")
        printErrors: false
        onLoaded: {
            try {
                root.pages = JSON.parse(text()).settingsPages ?? [];
            } catch (e) {
                console.warn("Settei: kanji-ui.json no válido", e);
            }
        }
    }

    // ── import / export settings.json ─────────────────────────────────────────────────────────
    property string ioMessage: ""
    property bool ioError: false
    readonly property string exportDir: {
        const d = Quickshell.env("XDG_DOCUMENTS_DIR");
        return d && d !== "" ? d : Paths.home + "/Documentos";
    }
    function stamp(): string {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "-" + p(d.getHours()) + p(d.getMinutes());
    }
    function exportTo(path: string): void {
        const dest = path !== "" ? path : exportDir + "/ocarinashell-ajustes-" + stamp() + ".json";
        exporter.dest = dest;
        exporter.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp -f "$1" "$2"', "sh", Paths.settings, dest];
        exporter.running = true;
    }
    function importFrom(path: string): void {
        let p = path.trim();
        if (p.startsWith("~/"))
            p = Paths.home + p.slice(1);
        if (p === "") {
            ioError = true;
            ioMessage = "Escribe la ruta del fichero";
            return;
        }
        importer.src = p;
        importer.command = ["cat", "--", p];
        importer.running = true;
    }
    Process {
        id: exporter
        property string dest: ""
        onExited: code => {
            root.ioError = code !== 0;
            root.ioMessage = code === 0 ? "Exportado a " + dest.replace(Paths.home, "~") : "No se pudo exportar";
        }
    }
    Process {
        id: importer
        property string src: ""
        stdout: StdioCollector {
            id: importOut
        }
        onExited: code => {
            if (code !== 0) {
                root.ioError = true;
                root.ioMessage = "No se pudo leer " + importer.src.replace(Paths.home, "~");
                return;
            }
            let obj = null;
            try {
                obj = JSON.parse(importOut.text);
            } catch (e) {
                root.ioError = true;
                root.ioMessage = "No es un JSON válido";
                return;
            }
            if (!obj || typeof obj !== "object" || Array.isArray(obj) || typeof obj.version !== "number") {
                root.ioError = true;
                root.ioMessage = "No parece un settings.json de OcarinaShell";
                return;
            }
            // keep the current file next to it before replacing anything
            backupBeforeImport.obj = obj;
            backupBeforeImport.command = ["cp", "-f", Paths.settings, Paths.settings + ".antes-de-importar-" + root.stamp()];
            backupBeforeImport.running = true;
        }
    }
    Process {
        id: backupBeforeImport
        property var obj: null
        onExited: code => {
            if (code !== 0) {
                root.ioError = true;
                root.ioMessage = "No se pudo guardar una copia del actual: no se importa";
                return;
            }
            Settings.replaceAll(obj);
            root.ioError = false;
            root.ioMessage = "Importado (copia del anterior junto a settings.json)";
        }
    }
}
