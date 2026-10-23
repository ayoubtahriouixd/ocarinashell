pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// niri over its JSON socket (docs/01-ARQUITECTURA §5). Two connections to $NIRI_SOCKET:
//  - events: sends "EventStream" once and keeps a model of workspaces, windows, layouts, overview and keyboard
//  - requests: actions and queries (one JSON line per request; niri answers each one in order)
// Tolerant parser (docs/06 capa 3.4): unknown events and fields are ignored, optional fields are never assumed,
// both sockets reconnect with backoff. No polling.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool available: socketPath !== "" && events.connected
    property string error: socketPath === "" ? "NIRI_SOCKET no definido" : ""

    property var workspaces: []          // sorted by output, then idx
    property var windows: ({})            // id → window object as niri sends it
    property int focusedWindowId: -1
    readonly property var focusedWindow: windows[focusedWindowId] ?? null
    property var focusedLayout: null      // layout of the focused window, kept up to date (WindowLayoutsChanged)
    // the last WINDOW that had the keyboard (a layer surface — Engawa, Torii… — makes focusedWindowId -1 but not this):
    // what «apply it to the window I was looking at» means (滑 Nameraka)
    property int lastWindowId: -1
    onFocusedWindowIdChanged: {
        focusedLayout = focusedWindow?.layout ?? null;
        if (focusedWindowId >= 0)
            lastWindowId = focusedWindowId;
    }
    readonly property string focusedOutput: {
        for (const w of workspaces)
            if (w.is_focused)
                return w.output ?? "";
        return "";
    }
    property bool overviewOpen: false
    property var keyboardLayouts: ({ names: [], current_idx: 0 })
    property var outputs: ({})            // name → output (from the "Outputs" request)

    signal configLoaded(bool failed)
    signal layoutSwitched(string name)
    signal windowOpened(var window)

    // ── queries used by the UI ────────────────────────────────────────────────────────────────
    function workspacesOn(output: string): var {
        return workspaces.filter(w => w.output === output && w.id !== stashWs);
    }

    // 端 the drop-down terminal hides on the empty workspace at the end of its monitor (bin/ocarina-quickterm):
    // that workspace is left out of the UI while it holds only that window and is not the active one.
    // An int, so bindings on workspacesOn() re-run only when the stash really changes (titles change constantly).
    readonly property string quicktermTitle: "端 Terminal desplegable"
    // The title is a contract shared with bin/ocarina-quickterm and config/niri/ocarina/rules.kdl (D-051).
    property int stashWs: -1
    // workspace id → number of windows; reassigned only when the counts change (not on every title update)
    property var windowCounts: ({})
    property string countsKey: ""
    function updateStash(): void {
        const counts = {};
        let ws = -1;
        for (const id in windows) {
            const w = windows[id];
            counts[w.workspace_id] = (counts[w.workspace_id] ?? 0) + 1;
            if (w.title === quicktermTitle)
                ws = w.workspace_id ?? -1;
        }
        const key = Object.keys(counts).sort().map(k => k + ":" + counts[k]).join(",");
        if (key !== countsKey) {
            countsKey = key;
            windowCounts = counts;
        }
        // hidden = not active, only the drop-down terminal in it, and nothing with windows after it on its monitor
        // (it was stashed at the end; a workspace you merely left it on stays visible, so Mod+N keeps matching)
        if (ws >= 0) {
            const w = workspaces.find(x => x.id === ws);
            if (!w || w.is_active || (counts[ws] ?? 0) !== 1
                    || workspaces.some(x => x.output === w.output && x.idx > w.idx && (counts[x.id] ?? 0) > 0))
                ws = -1;
        }
        if (stashWs !== ws)
            stashWs = ws;
    }
    onWindowsChanged: updateStash()
    onWorkspacesChanged: updateStash()
    function windowsOn(workspaceId: int): var {
        const out = [];
        for (const id in windows)
            if (windows[id].workspace_id === workspaceId)
                out.push(windows[id]);
        return out;
    }

    // ── actions ───────────────────────────────────────────────────────────────────────────────
    function action(name: string, args: var): void {
        const a = {};
        a[name] = args ?? {};
        send({ Action: a });
    }
    function focusWorkspace(id: int): void {
        action("FocusWorkspace", { reference: { Id: id } });
    }
    function focusWorkspaceRelative(delta: int): void {
        action(delta > 0 ? "FocusWorkspaceDown" : "FocusWorkspaceUp", {});
    }
    function focusWindow(id: int): void {
        action("FocusWindow", { id: id });
    }
    function setWorkspaceName(id: int, name: string): void {
        if (name === "")
            action("UnsetWorkspaceName", { reference: { Id: id } });
        else
            action("SetWorkspaceName", { name: name, workspace: { Id: id } });
    }
    function refreshOutputs(): void {
        if (!req.connected) {
            req.connected = true;     // onConnectedChanged asks for the outputs
            return;
        }
        pending.push("Outputs");
        req.write('"Outputs"\n');
        req.flush();
    }

    property var queue: []      // requests waiting for the socket
    property var pending: []    // what each answer in flight belongs to
    function send(obj: var): void {
        const line = JSON.stringify(obj) + "\n";
        if (!req.connected) {
            // keep only recent actions: a click from 2 s ago must not fire after a reconnection
            queue = queue.filter(q => Date.now() - q.t < 2000).concat([{ t: Date.now(), line: line }]);
            req.connected = true;
            return;
        }
        pending.push("Action");
        req.write(line);
        req.flush();
    }

    // ── event model ───────────────────────────────────────────────────────────────────────────
    function sortWs(list: var): var {
        return list.slice().sort((a, b) => (a.output ?? "").localeCompare(b.output ?? "") || a.idx - b.idx);
    }
    function setWindows(list: var): void {
        const m = {};
        let focused = -1;
        for (const w of list) {
            m[w.id] = w;
            if (w.is_focused)
                focused = w.id;
        }
        windows = m;
        focusedWindowId = focused;
    }
    function patchWindow(id: int, patch: var): void {
        if (!(id in windows))
            return;
        const m = Object.assign({}, windows);
        m[id] = Object.assign({}, m[id], patch);
        windows = m;
    }

    function handle(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!ev || typeof ev !== "object")
            return;
        const [type] = Object.keys(ev);
        const d = ev[type] ?? {};
        switch (type) {
        case "WorkspacesChanged":
            workspaces = sortWs(d.workspaces ?? []);
            break;
        case "WorkspaceActivated": {
            const ws = workspaces.find(w => w.id === d.id);
            if (!ws)
                break;
            workspaces = workspaces.map(w => {
                if (w.output !== ws.output && !d.focused)
                    return w;
                const c = Object.assign({}, w);
                if (w.output === ws.output)
                    c.is_active = w.id === d.id;
                if (d.focused)
                    c.is_focused = w.id === d.id;
                return c;
            });
            break;
        }
        case "WorkspaceActiveWindowChanged":
            workspaces = workspaces.map(w => w.id === d.workspace_id
                ? Object.assign({}, w, { active_window_id: d.active_window_id }) : w);
            break;
        case "WorkspaceUrgencyChanged":
            workspaces = workspaces.map(w => w.id === d.id ? Object.assign({}, w, { is_urgent: !!d.urgent }) : w);
            break;
        case "WindowsChanged":
            setWindows(d.windows ?? []);
            break;
        case "WindowOpenedOrChanged": {
            const w = d.window;
            if (!w)
                break;
            const isNew = !(w.id in windows);
            const m = Object.assign({}, windows);
            if (w.is_focused) {
                for (const id in m)
                    if (m[id].is_focused && Number(id) !== w.id)
                        m[id] = Object.assign({}, m[id], { is_focused: false });
                focusedWindowId = w.id;
            }
            m[w.id] = w;
            windows = m;
            if (isNew)
                windowOpened(w);
            break;
        }
        case "WindowClosed": {
            if (!(d.id in windows))
                break;
            const m = Object.assign({}, windows);
            delete m[d.id];
            windows = m;
            if (focusedWindowId === d.id)
                focusedWindowId = -1;
            if (lastWindowId === d.id)
                lastWindowId = -1;
            break;
        }
        case "WindowFocusChanged": {
            const m = Object.assign({}, windows);
            for (const id in m)
                if (m[id].is_focused !== (Number(id) === d.id))
                    m[id] = Object.assign({}, m[id], { is_focused: Number(id) === d.id });
            windows = m;
            focusedWindowId = d.id ?? -1;
            break;
        }
        case "WindowUrgencyChanged":
            patchWindow(d.id, { is_urgent: !!d.urgent });
            break;
        case "WindowLayoutsChanged":
            // updating the windows map here would re-evaluate every binding on each resize: only the FOCUSED window's
            // layout is kept, apart (滑 Nameraka's «Automático» needs to know when it goes full screen)
            for (const ch of (d.changes ?? []))
                if (ch?.[0] === focusedWindowId)
                    focusedLayout = ch[1] ?? null;
            break;
        case "WindowFocusTimestampChanged":
            // only used for ordering; not worth a model update (and a repaint) on every focus change
            break;
        case "KeyboardLayoutsChanged":
            keyboardLayouts = d.keyboard_layouts ?? keyboardLayouts;
            break;
        case "KeyboardLayoutSwitched":
            if (typeof d.idx !== "number")
                break;                      // a renamed field must not leave current_idx undefined
            keyboardLayouts = Object.assign({}, keyboardLayouts, { current_idx: d.idx });
            layoutSwitched((keyboardLayouts.names ?? [])[d.idx] ?? "");
            break;
        case "OverviewOpenedOrClosed":
            overviewOpen = !!d.is_open;
            break;
        case "ConfigLoaded":
            configLoaded(!!d.failed);
            break;
        default:
            break;   // unknown or uninteresting event: ignore (forward compatible)
        }
    }

    function handleReply(line: string): void {
        const kind = pending.shift() ?? "";
        let r;
        try {
            r = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (r && r.Err)
            console.warn("Niri: la petición", kind, "falló:", r.Err);
        else if (kind === "Outputs" && r && r.Ok && r.Ok.Outputs)
            outputs = r.Ok.Outputs;
    }

    // ── sockets ───────────────────────────────────────────────────────────────────────────────
    property int backoff: 250

    Socket {
        id: events
        path: root.socketPath
        connected: root.socketPath !== ""
        onConnectedChanged: {
            if (connected) {
                root.backoff = 250;
                root.error = "";
                write('"EventStream"\n');
                flush();
            } else {
                retry.start();
            }
        }
        onError: e => {
            root.error = "socket de eventos: " + e;
            retry.start();
        }
        parser: SplitParser {
            onRead: line => root.handle(line)
        }
    }

    Socket {
        id: req
        path: root.socketPath
        connected: root.socketPath !== ""
        onConnectedChanged: {
            root.pending = [];        // answers of the old connection will never come
            if (!connected) {
                retry.start();
                return;
            }
            root.backoff = 250;
            root.refreshOutputs();
            const q = root.queue;
            root.queue = [];
            for (const item of q) {
                if (Date.now() - item.t > 2000)
                    continue;
                root.pending.push("Action");
                write(item.line);
            }
            flush();
        }
        onError: e => {
            root.pending = [];
            retry.start();
        }
        parser: SplitParser {
            onRead: line => root.handleReply(line)
        }
    }

    // Runs only while disconnected (exponential backoff up to 5 s).
    Timer {
        id: retry
        interval: root.backoff
        onTriggered: {
            root.backoff = Math.min(5000, root.backoff * 2);
            if (!events.connected)
                events.connected = true;
            if (!req.connected)
                req.connected = true;
        }
    }

    // Outputs only change with hot-plug: Quickshell tells us, then we ask niri once.
    Connections {
        target: Quickshell
        function onScreensChanged() { root.refreshOutputs(); }
    }
}
