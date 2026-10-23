pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 復元 Fukugen — restore the session (docs/07-IDEAS, fase 06). Settings: session { restore: ask|auto|off, exclude[] }.
// Save: ~/.local/state/ocarinashell/session.json, per window: app-id, .desktop entry, workspace (index and name), output,
// width, floating and size. Written ≤ 30 s after a window opens or closes (niri events, no polling — it survives a power
// cut) and always in Dengen's farewell. Layout data is read from `niri msg --json` only at save time.
// Restore: at login (a marker in $XDG_RUNTIME_DIR tells a login from a shell restart) it asks «¿Restaurar tu sesión?»,
// relaunches 3 at a time and places each window when it appears (by id, focus untouched); 20 s without it → skipped.
// Never restored: Fune (Windows) apps, games, `ssh · *` terminals (never reconnects to servers), wl-mirror, shell windows.
Singleton {
    id: root

    readonly property string file: Paths.state + "/session.json"
    readonly property string mode: Settings.data.session.restore
    property var saved: []               // last snapshot written (or read)
    property double savedAt: 0
    property bool restoring: false
    property var queue: []               // windows still to launch
    property var pending: []             // launched, waiting for their window: { item, deadline }
    property var report: ({ placed: 0, skipped: 0, total: 0 })

    // ------------------------------------------------------------------ what never comes back
    function excluded(w: var): bool {
        const app = w.app_id ?? "", title = w.title ?? "";
        if (app === "" || /^org\.quickshell$/.test(app))
            return true;
        if (/^ssh · /.test(title))
            return true;
        if (/^(steam_app_\d+|gamescope|steam|.*\.exe)$/i.test(app))                 // games
            return true;
        if (/(winapps|freerdp|rdesktop|remoteapp)/i.test(app) || /\bRAIL\b/.test(title))   // 船 Fune
            return true;
        if (/wl-mirror|wl_mirror/i.test(app))
            return true;
        return (Settings.data.session.exclude ?? []).some(x => x !== "" && (x === app || app.toLowerCase().includes(String(x).toLowerCase())));
    }

    function isTerminal(app: string): bool {
        return /ghostty|kitty|alacritty|foot|wezterm|konsole|gnome-terminal/i.test(app);
    }
    // fish puts the working directory in Ghostty's title ("/home/a/x - fish", "~/ocarinashell", "nvim ~/x/y"):
    // the first token that looks like a path
    function cwdFromTitle(title: string): string {
        const m = /(?:^|\s)((?:~|\/)\S*)/.exec(title ?? "");
        if (!m)
            return "";
        return m[1].startsWith("~") ? Paths.home + m[1].slice(1) : m[1];
    }

    // ------------------------------------------------------------------ save
    function scheduleSave(): void {
        if (!saveTimer.running)
            saveTimer.start();
    }
    signal didSave()
    property bool farewell: false          // Dengen's goodbye: an empty desktop is a valid session to keep
    function saveNow(isFarewell: bool): void {
        farewell = isFarewell === true;
        saveTimer.stop();
        snapshot.running = false;
        snapshot.running = true;
    }
    Timer {
        id: saveTimer
        interval: 30000
        onTriggered: root.saveNow()
    }
    Connections {
        target: Niri
        function onWindowOpened(w) {
            if (root.restoring)
                root.claim(w);
            root.scheduleSave();
        }
        function onWindowsChanged() {
            const n = Object.keys(Niri.windows).length;
            if (n !== root.lastCount) {
                root.lastCount = n;
                root.scheduleSave();
            }
        }
    }
    property int lastCount: -1

    Process {
        id: snapshot
        command: ["sh", "-c", "niri msg --json windows && niri msg --json workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.write(text)
        }
    }
    function write(text: string): void {
        const lines = text.split("\n").filter(l => l.trim() !== "");
        if (lines.length < 2 || root.restoring)
            return;
        let wins, wss;
        try {
            wins = JSON.parse(lines[0]);
            wss = JSON.parse(lines[1]);
        } catch (e) {
            console.warn("Fukugen: respuesta de niri ilegible:", e);
            return;
        }
        const wsById = {};
        for (const ws of wss)
            wsById[ws.id] = ws;
        const out = [];
        for (const w of wins) {
            if (root.excluded(w))
                continue;
            const ws = wsById[w.workspace_id] ?? null;
            const entry = DesktopEntries.heuristicLookup(w.app_id);
            const l = w.layout ?? {};
            const pos = l.pos_in_scrolling_layout ?? [0, 0];
            const size = l.window_size ?? [0, 0];
            out.push({
                appId: w.app_id,
                desktop: entry?.id ?? "",
                title: w.title ?? "",
                cwd: root.isTerminal(w.app_id) ? root.cwdFromTitle(w.title) : "",
                output: ws?.output ?? "",
                wsIdx: ws?.idx ?? 1,
                wsName: ws?.name ?? "",
                column: pos ? pos[0] : 0,
                floating: !!w.is_floating,
                width: Math.round(size[0] ?? 0),
                height: Math.round(size[1] ?? 0)
            });
        }
        out.sort((a, b) => a.output.localeCompare(b.output) || a.wsIdx - b.wsIdx || a.column - b.column);
        // an empty desktop (last window just closed) never overwrites a session — except when leaving on purpose
        if (out.length === 0 && root.saved.length > 0 && !root.farewell) {
            root.didSave();
            return;
        }
        root.saved = out;
        root.savedAt = Date.now();
        store.setText(JSON.stringify({ version: 1, savedAt: new Date().toISOString(), windows: out }, null, 1) + "\n");
        root.didSave();
    }
    // session.json may be old, hand-edited or broken: keep only well-formed entries
    function sanitize(list: var): var {
        if (!Array.isArray(list))
            return [];
        return list.filter(w => w && typeof w.appId === "string" && w.appId !== "").map(w => ({
            appId: w.appId, desktop: String(w.desktop ?? ""), title: String(w.title ?? ""), cwd: String(w.cwd ?? ""),
            output: String(w.output ?? ""), wsIdx: Math.max(1, Math.min(99, parseInt(w.wsIdx) || 1)),
            wsName: String(w.wsName ?? ""), column: parseInt(w.column) || 0, floating: w.floating === true,
            width: Math.max(0, Math.min(10000, parseInt(w.width) || 0)), height: Math.max(0, Math.min(10000, parseInt(w.height) || 0))
        }));
    }
    FileView {
        id: store
        path: root.file
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                root.saved = root.sanitize(JSON.parse(text()).windows);
            } catch (e) {
                root.saved = [];
            }
        }
    }

    // ------------------------------------------------------------------ restore
    function summary(list: var): string {
        const ws = new Set(list.map(w => w.output + "/" + w.wsIdx));
        return list.length + (list.length === 1 ? " app" : " apps") + " · " + ws.size + (ws.size === 1 ? " espacio" : " espacios");
    }

    function restore(): string {
        if (restoring)
            return "ya restaurando";
        store.reload();
        const list = root.saved.filter(w => !root.excluded({ app_id: w.appId, title: w.title }));
        if (list.length === 0)
            return "no hay sesión guardada";
        restoring = true;
        queue = list.slice();
        pending = [];
        report = { placed: 0, skipped: 0, total: list.length };
        launchMore();
        return "restaurando " + summary(list);
    }

    // Up to 3 at a time, in waves by workspace (niri's workspaces are dynamic: moving a window to index 3 while 2 is
    // still empty lands it on 2), and never two of the same app at once (windows are matched by app-id, so two
    // Ghostty launched together could swap places and folders).
    function launchMore(): void {
        let q = queue.slice();
        let p = pending.slice();
        let skipped = 0;
        while (p.length < 3) {
            const wave = Math.min(...q.concat(p.map(x => x.item)).map(it => it.wsIdx));
            const i = q.findIndex(it => it.wsIdx === wave && !p.some(x => x.item.appId === it.appId));
            if (i < 0) {
                // nothing launchable now; with nothing pending either, skip the stuck item so restore always ends
                if (p.length === 0 && q.length > 0) {
                    q.shift();
                    skipped++;
                    continue;
                }
                break;
            }
            const item = q[i];
            q.splice(i, 1);
            if (launch(item))
                p.push({ item: item, deadline: Date.now() + 20000 });
            else
                skipped++;
        }
        queue = q;
        pending = p;
        if (skipped > 0)
            report = Object.assign({}, report, { skipped: report.skipped + skipped });
        if (pending.length === 0 && queue.length === 0)
            finish();
    }

    function launch(item: var): bool {
        if (item.cwd !== "" && /ghostty/i.test(item.appId)) {
            Quickshell.execDetached(["sh", "-c", 'd="$1"; [ -d "$d" ] || d="$HOME"; exec ghostty --working-directory="$d"',
                                     "sh", item.cwd]);
            return true;
        }
        const entry = (item.desktop !== "" ? DesktopEntries.byId(item.desktop) : null) ?? DesktopEntries.heuristicLookup(item.appId);
        if (!entry) {
            console.warn("Fukugen: sin entrada .desktop para", item.appId);
            return false;
        }
        entry.execute();
        return true;
    }

    // a new window appeared: if it is one we are waiting for, put it where it was
    function claim(w: var): void {
        const i = pending.findIndex(p => p.item.appId === w.app_id);
        if (i < 0)
            return;
        const item = pending[i].item;
        pending = pending.filter((_, k) => k !== i);
        place(w.id, item, w);
        report = Object.assign({}, report, { placed: report.placed + 1 });
        launchMore();
    }

    function place(id: int, item: var, w: var): void {
        const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
        if (item.output !== "" && ws && ws.output !== item.output && Niri.workspaces.some(x => x.output === item.output))
            Niri.action("MoveWindowToMonitor", { id: id, output: item.output });
        const named = item.wsName !== "" && Niri.workspaces.some(x => x.name === item.wsName);
        Niri.action("MoveWindowToWorkspace", { window_id: id, focus: false,
                                               reference: named ? { Name: item.wsName } : { Index: item.wsIdx } });
        if (item.floating !== !!w.is_floating)
            Niri.action("ToggleWindowFloating", { id: id });
        if (item.width > 0)
            Niri.action("SetWindowWidth", { id: id, change: { SetFixed: item.width } });
        if (item.floating && item.height > 0)
            Niri.action("SetWindowHeight", { id: id, change: { SetFixed: item.height } });
    }

    Timer {
        running: root.restoring
        interval: 1000
        repeat: true
        onTriggered: {
            const now = Date.now();
            const late = root.pending.filter(p => p.deadline < now);
            if (late.length === 0)
                return;
            for (const p of late)
                console.warn("Fukugen: no apareció en 20 s, se ignora:", p.item.appId);
            root.pending = root.pending.filter(p => p.deadline >= now);
            root.report = Object.assign({}, root.report, { skipped: root.report.skipped + late.length });
            root.launchMore();
        }
    }

    function finish(): void {
        if (!restoring)
            return;
        restoring = false;
        Osd.show("info", 0, "Sesión restaurada · " + report.placed + "/" + report.total, "history");
        scheduleSave();
    }

    function status(): string {
        return JSON.stringify({ mode: mode, saved: saved.length, savedAt: savedAt > 0 ? new Date(savedAt).toISOString() : "",
                                restoring: restoring, queue: queue.length, pending: pending.map(p => p.item.appId),
                                report: report });
    }

    // ------------------------------------------------------------------ at login
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ocarinashell/session-started"
    Process {
        id: loginCheck
        // exit 0 = first start of the shell in this login (the runtime dir is wiped at logout)
        command: ["sh", "-c", 'test -e "$1" && exit 1; mkdir -p "$(dirname "$1")" && : > "$1"', "sh", root.marker]
        onExited: code => {
            if (code !== 0 || root.mode === "off")
                return;
            offerTimer.start();
        }
    }
    // give niri and the user a moment (and let the saved file load) before asking
    Timer {
        id: offerTimer
        interval: 4000
        onTriggered: {
            const list = root.saved.filter(w => !root.excluded({ app_id: w.appId, title: w.title }));
            if (list.length === 0)
                return;
            if (root.mode === "auto") {
                root.restore();
                return;
            }
            ask.command = ["notify-send", "-a", "OcarinaShell", "-i", "history", "-A", "restore=Restaurar",
                           "-A", "later=Ahora no", "¿Restaurar tu sesión?", root.summary(list)];
            ask.running = true;
        }
    }
    Process {
        id: ask
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "restore") root.restore()
        }
    }

    Component.onCompleted: {
        store.reload();
        loginCheck.running = true;
    }
}
