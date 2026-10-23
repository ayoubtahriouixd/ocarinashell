pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 手帳 Techō's data: plain Markdown notes in data/notas/*.md (editable with any editor, backed up with the home).
// The open note is saved atomically 300 ms after the last keystroke and when Techō closes, so killing the shell
// loses at most that last instant. The last open note is remembered in state/techo.json. Search uses ripgrep.
// Techō listens only to `opened` (emitted once the state is consistent) and `appended`; it never reads a half-
// switched state, so a keystroke can never overwrite one note with another's text.
Singleton {
    id: root

    readonly property string dir: Paths.data + "/notas"
    property var notes: []              // [{ file, title }] in name order (new notes are timestamped: chronological)
    property string current: ""         // file name of the open note
    property string text: ""            // its contents as last loaded/edited
    property bool dirty: false
    property bool loaded: false         // `text` belongs to `current` and may be edited
    property var results: []            // search: [{ file, title, line }]
    property string searchedFor: ""
    property var pendingLines: []       // `ocarina note` lines that arrived before any note was loaded

    signal opened                       // current/text changed together: the editor reloads
    signal appended(string line)        // a line was added to the open note from outside the editor

    function title(file: string, body: string): string {
        // only the head of the document is looked at (this runs on every keystroke)
        const head = (body ?? "").slice(0, 400).replace(/^\s+/, "");
        const nl = head.indexOf("\n");
        const t = (nl < 0 ? head : head.slice(0, nl)).replace(/^#+\s*/, "").trim();
        return t !== "" ? t.slice(0, 40) : file.replace(/\.md$/, "");
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }
    function open(file: string): void {
        if (file === current && loaded)
            return;
        flush();
        loaded = false;
        text = "";
        current = file;
        noteFile.path = "";             // force a fresh read even if the path is the same
        noteFile.path = dir + "/" + file;
        state.setText(JSON.stringify({ current: file }));
    }
    function create(): void {
        flush();
        const d = new Date();
        const pad = n => String(n).padStart(2, "0");
        const base = "nota-" + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "-" + pad(d.getHours())
            + pad(d.getMinutes()) + pad(d.getSeconds());
        let file = base + ".md";
        for (let i = 2; notes.some(n => n.file === file); i++)
            file = base + "-" + i + ".md";
        // consistent state first, then one notification
        loaded = false;
        noteFile.path = "";
        text = "";
        dirty = false;
        current = file;
        notes = notes.concat([{ file: file, title: "Nota nueva" }]);
        loaded = true;
        state.setText(JSON.stringify({ current: file }));
        opened();
    }
    // the editor reports every change; the save is debounced
    function edit(body: string): void {
        if (!loaded || body === text)
            return;
        text = body;
        dirty = true;
        saveTimer.restart();
        const i = notes.findIndex(n => n.file === current);
        const t = title(current, body);
        if (i >= 0 && notes[i].title !== t) {
            const copy = notes.slice();
            copy[i] = { file: current, title: t };
            notes = copy;
        }
    }
    function save(): void {
        saveTimer.stop();
        if (!dirty || current === "" || !loaded)
            return;
        if (noteFile.path === "")
            noteFile.path = dir + "/" + current;    // a new note: its file is written for the first time
        noteFile.setText(text);
        dirty = false;
    }
    function flush(): void {
        if (dirty)
            save();
    }
    // notes are moved to notas/.papelera (never deleted outright; same name → numbered backup)
    function trash(file: string): void {
        if (file === "")
            return;
        if (file === current) {
            saveTimer.stop();
            dirty = false;
            loaded = false;
        }
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$0/.papelera" && mv --backup=numbered -- "$0/$1" "$0/.papelera/$1"', dir, file]);
        notes = notes.filter(n => n.file !== file);
        if (file === current) {
            current = "";
            text = "";
            if (notes.length > 0)
                open(notes[notes.length - 1].file);
            else
                create();
        }
    }
    // append a line to the open note: `ocarina note "texto"`. Before any note is loaded, the remembered one is
    // opened first and the line waits for it.
    function append(line: string): void {
        if (!loaded) {
            pendingLines = pendingLines.concat([line]);
            if (current === "" && !listProc.running)
                refresh();
            return;
        }
        edit((text === "" || text.endsWith("\n") ? text : text + "\n") + line + "\n");
        save();
        appended(line);
    }
    function flushPending(): void {
        const lines = pendingLines;
        pendingLines = [];
        for (const l of lines)
            append(l);
    }
    function search(q: string): void {
        searchedFor = q;
        if (q.trim() === "") {
            results = [];
            return;
        }
        if (searchProc.running) {
            searchProc.queued = true;           // relaunched with the latest query when the old one exits
            searchProc.signal(15);
            return;
        }
        searchProc.query = q.trim();
        searchProc.command = ["rg", "--ignore-case", "--fixed-strings", "--max-count", "1", "--no-heading", "--null",
                              "--with-filename", "--glob", "*.md", "--", q.trim(), root.dir];
        searchProc.running = true;
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.save()
    }

    Process {
        id: listProc
        // "file<TAB>first non-empty line" for every note (one awk for all of them)
        command: ["sh", "-c", 'mkdir -p "$0" && cd "$0" && for f in *.md; do [ -e "$f" ] && printf "%s\\n" "$f"; done '
                 + '| while IFS= read -r f; do printf "%s\\t%s\\n" "$f" "$(awk \'NF { print substr($0, 1, 80); exit }\' "$f")"; done', root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    const tab = l.indexOf("\t");
                    if (tab > 0)
                        out.push({ file: l.slice(0, tab), title: root.title(l.slice(0, tab), l.slice(tab + 1)) });
                }
                // keep a new note that has no file yet
                if (root.current !== "" && !out.some(n => n.file === root.current) && root.loaded)
                    out.push({ file: root.current, title: root.title(root.current, root.text) });
                root.notes = out;
                if (root.current === "" || !out.some(n => n.file === root.current)) {
                    if (out.length === 0)
                        root.create();
                    else
                        root.open(out.some(n => n.file === root.wanted) ? root.wanted : out[out.length - 1].file);
                }
                if (root.loaded)
                    root.flushPending();
            }
        }
    }
    Process {
        id: searchProc
        property string query: ""
        property bool queued: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (searchProc.query !== root.searchedFor.trim())
                    return;                             // output of a query that is no longer current
                const out = [];
                for (const l of text.split("\n")) {
                    // --null: "<path>\0<line text>"
                    const z = l.indexOf("\0");
                    if (z < 0)
                        continue;
                    const file = l.slice(0, z).split("/").pop();
                    const n = root.notes.find(x => x.file === file);
                    out.push({ file: file, title: n ? n.title : file, line: l.slice(z + 1).trim().slice(0, 90) });
                }
                root.results = out;
            }
        }
        onExited: {
            if (queued) {
                queued = false;
                root.search(root.searchedFor);
            }
        }
    }

    FileView {
        id: noteFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.loaded)
                return;                                 // our own write echoing back
            root.text = text();
            root.dirty = false;
            root.loaded = true;
            root.opened();
            root.flushPending();
        }
        onLoadFailed: {
            if (root.loaded || path === "")
                return;
            root.text = "";
            root.loaded = true;
            root.opened();
            root.flushPending();
        }
    }

    // last open note
    property string wanted: ""
    FileView {
        id: state
        atomicWrites: true
        path: Paths.state + "/techo.json"
        printErrors: false
        onLoaded: {
            try {
                root.wanted = JSON.parse(text()).current ?? "";
            } catch (e) {}
        }
    }
}
