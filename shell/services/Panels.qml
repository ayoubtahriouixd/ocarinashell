pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Which popup panel is open (one at a time): "engawa" | "notifications" | "koyomi" | "kura" | "". Opening one closes the
// other. The panel host shows it on the screen niri has focused when it was opened.
Singleton {
    id: root

    // the control a panel focused by itself when it opened: no FocusRing there until the keyboard moves the focus
    // (opening with the mouse must not draw a ring; the first Tab or arrow that changes the focus shows it)
    property Item quietFocus: null

    property string open: ""
    property string page: ""          // detail page inside Engawa: "" | "wifi" | "bluetooth" | "audio"
    property string screen: ""

    readonly property var pages: ["", "wifi", "bluetooth", "audio", "fluido", "night", "record", "vpn"]
    property bool blurActive: false     // set by PanelHostBlur when the compositor blur is really in use
    property bool islandHoverTest: false   // IPC `island hover true` (captures without moving the pointer)
    property bool hirobaClosing: false     // 広場 is shrinking back into its pill (the island metrics stay frozen)
    // the island's real rectangle on its screen (x centred): 広場 grows out of it and shrinks back into it
    property real islandW: 210
    property real islandH: 30
    property real islandR: 15

    // a typed `string` parameter that was not passed arrives as "undefined" (QV4): normalise
    function clean(p: string): string {
        return (p === undefined || p === null || p === "undefined" || pages.indexOf(p) < 0) ? "" : p;
    }
    // 広場 lives where the island is (the primary screen), whatever screen has the focus
    function screenFor(name: string): string {
        return name === "hiroba" ? Displays.primary : Niri.focusedOutput;
    }
    function toggle(name: string, page: string): void {
        const pg = clean(page);
        if (open === name && (pg === "" || pg === root.page)) {
            close();
            return;
        }
        screen = screenFor(name);
        root.page = pg;
        open = name;
    }
    function show(name: string, page: string): void {
        screen = screenFor(name);
        root.page = clean(page);
        open = name;
    }
    // touch: pull a panel down from the bar following the finger (docs/02-DISENO §6)
    property string dragging: ""
    property real dragProgress: 0
    function beginDrag(name: string): void {
        if (open !== "")
            return;
        screen = screenFor(name);
        page = "";
        dragProgress = 0;
        dragging = name;
    }
    function updateDrag(p: real): void {
        dragProgress = Math.max(0, Math.min(1, p));
    }
    function endDrag(): void {
        const name = dragging;
        if (name !== "" && dragProgress > 0.4)
            open = name;                  // before clearing `dragging`: the host keeps the same panel instance
        dragging = "";
        dragProgress = 0;
    }

    function close(): void {
        open = "";
        page = "";
    }

    // workspace rename, edited inside the island (Shima). -1 = not renaming
    property int renameId: -1
    property string renameName: ""
    property int renameFrom: -1         // workspace focused when the edit began (moving away cancels it)
    property int renameWindow: -1       // window focused when it began
    property string renameDraft: ""     // what the field holds (IPC `workspace editing`, tests)
    function startRename(id: int): void {
        const ws = id >= 0 ? Niri.workspaces.find(w => w.id === id) : Niri.workspaces.find(w => w.is_focused);
        if (!ws)
            return;
        close();
        renameName = ws.name ?? "";
        renameFrom = Niri.workspaces.find(w => w.is_focused)?.id ?? -1;
        renameWindow = Niri.focusedWindowId;
        renameDraft = renameName;
        renameId = ws.id;
    }
    function endRename(name: var): void {
        // name: string to apply ("" unsets) or null to cancel
        if (renameId >= 0 && name !== null && name !== undefined)
            Niri.setWorkspaceName(renameId, String(name).trim());
        renameId = -1;
    }
}
