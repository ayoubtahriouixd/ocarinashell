pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../modules/torii/fuzzy.js" as Fuzzy

// 蔵 Kura's data: the cliphist history (read when Kura opens, never polled), image thumbnails in the cache, pinned
// entries (kept in data/kura/pins.json, they survive a wipe) and Iro's last colours. Sensitive copies never get
// here: cliphist skips them (CLIPBOARD_STATE=sensitive, set by password managers). Entries that look like a secret
// are masked in the list. `clipboard.dbPath` points to another cliphist database (tests).
Singleton {
    id: root

    property var items: []             // [{ id, text, image, meta, secret, n }]
    property var pins: []              // [{ kind: "text", text } | { kind: "image", path, meta }]
    property var colors: []            // Iro: last 12 picked colours ("#rrggbb")
    property bool loading: false
    property var thumbReady: ({})      // ids whose thumbnail exists (set when the helper finishes)
    readonly property string thumbDir: Paths.cache + "/kura"
    readonly property string pinDir: Paths.data + "/kura"
    readonly property var env: Settings.data.clipboard.dbPath !== "" ? { CLIPHIST_DB_PATH: Settings.data.clipboard.dbPath } : {}
    readonly property string helper: Paths.bin + "/ocarina-clip"

    function thumb(id: int): string {
        return thumbReady[id] ? "file://" + thumbDir + "/" + id + ".png" : "";
    }

    function refresh(): void {
        if (list.running)
            return;
        loading = true;
        list.running = true;
        pinsFile.reload();
        iroFile.reload();       // written by Iro
    }

    // a password-like token: no spaces, 8–128 chars, 3+ character classes, not a URL/path/e-mail
    function looksSecret(t: string): bool {
        if (t.length < 8 || t.length > 128 || /\s/.test(t) || /^(https?:|file:|\/|~\/)/.test(t) || /^[^@]+@[^@]+\.[a-z]+$/i.test(t))
            return false;
        const classes = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^A-Za-z0-9]/].filter(r => r.test(t)).length;
        return classes >= 3;
    }

    // filtered view for the search box (same fuzzy rules as Torii, contiguous words for long previews)
    function filter(q: string): var {
        if (q === "")
            return items;
        const nq = Fuzzy.norm(q);
        return items.filter(it => !it.secret && (Fuzzy.word(nq, it.n, true) !== null));
    }

    function run(args: list<string>): void {
        Quickshell.execDetached({ command: [helper].concat(args), environment: root.env });
    }
    function copy(item: var): void {
        run(["copy", String(item.id)]);
    }
    // copy, then type the paste shortcut into the window that had the focus (terminals use Ctrl+Shift+V)
    function copyAndPaste(item: var, terminal: bool): void {
        Quickshell.execDetached({
            command: ["sh", "-c", '"$0" copy "$1" && "$0" paste "$2"', helper, String(item.id), terminal ? "terminal" : ""],
            environment: root.env
        });
    }
    function remove(item: var): void {
        items = items.filter(it => it.id !== item.id);
        run(["delete", String(item.id)]);
    }
    function wipe(): void {
        items = [];
        run(["wipe", thumbDir]);
    }

    // ── pins ─────────────────────────────────────────────────────────────────────────────────
    function pin(item: var): void {
        // one at a time (a second request would overwrite the first one's command); secrets are never pinned:
        // pins.json is a plain file that backups copy
        if (pinProc.running || item.secret)
            return;
        if (item.image) {
            const path = pinDir + "/pin-" + Date.now() + ".png";
            pinProc.pending = { kind: "image", path: path, meta: item.meta };
            pinProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && cliphist decode "$0" > "$1"', String(item.id), path];
        } else {
            pinProc.pending = { kind: "text" };
            pinProc.command = ["sh", "-c", 'mkdir -p "$1" && cliphist decode "$0"', String(item.id), pinDir];
        }
        pinProc.running = true;
    }
    function unpin(index: int): void {
        const p = pins[index];
        if (p?.kind === "image")
            Quickshell.execDetached(["rm", "-f", "--", p.path]);
        pins = pins.filter((_, i) => i !== index);
        savePins();
    }
    function copyPin(p: var): void {
        if (p.kind === "image")
            run(["copy-file", p.path]);
        else
            run(["copy-pin", pinDir + "/pins.json", String(pins.indexOf(p))]);
    }
    function savePins(): void {
        pinsFile.setText(JSON.stringify({ version: 1, pins: pins }, null, 1));
    }
    function copyColor(hex: string): void {
        Quickshell.execDetached(["wl-copy", "--", hex]);
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [], images = [];
                const mask = Settings.data.clipboard.maskSecrets;
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const id = parseInt(line.slice(0, tab));
                    const body = line.slice(tab + 1);
                    // "[[ binary data 14 KiB png 1600x1000 ]]"
                    const m = /^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp|svg\+xml) (\d+x\d+) \]\]$/.exec(body);
                    if (m) {
                        out.push({ id: id, text: "", image: true, meta: m[2].toUpperCase() + " · " + m[3].replace("x", "×") + " · " + m[1],
                                   secret: false, n: "" });
                        if (images.length < 60)
                            images.push(String(id));
                    } else {
                        out.push({ id: id, text: body, image: false, meta: "", secret: mask && root.looksSecret(body),
                                   n: Fuzzy.norm(body) });
                    }
                }
                root.items = out;
                root.loading = false;
                thumbs.ids = images;
                thumbs.command = [root.helper, "thumbs", root.thumbDir].concat(images);
                if (!thumbs.running)
                    thumbs.running = true;
                else
                    thumbs.again = true;            // rerun with the latest ids when the current run ends
            }
        }
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }
    Process {
        id: thumbs
        property var ids: []
        property bool again: false
        environment: root.env
        onExited: {
            if (again) {
                again = false;
                running = true;
                return;
            }
            const r = {};
            for (const id of ids)
                r[id] = true;
            root.thumbReady = r;
        }
    }
    Process {
        id: pinProc
        property var pending: null
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                const p = pinProc.pending;
                if (!p)
                    return;
                if (p.kind === "text") {
                    if (text === "" || root.pins.some(x => x.kind === "text" && x.text === text))
                        return;
                    p.text = text;
                }
                root.pins = [p].concat(root.pins);
                root.savePins();
            }
        }
    }
    FileView {
        id: pinsFile
        path: root.pinDir + "/pins.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.pins = JSON.parse(text()).pins ?? [];
            } catch (e) {
                root.pins = [];
            }
        }
        onLoadFailed: root.pins = []
    }
    FileView {
        id: iroFile
        path: Paths.state + "/iro.json"
        printErrors: false
        onLoaded: {
            try {
                root.colors = (JSON.parse(text()).recent ?? []).slice(0, 12);
            } catch (e) {
                root.colors = [];
            }
        }
    }
}
