pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.panels

// Host for the popup panels (Engawa, notification centre, 広場 Hiroba, Kura, Techō, Mihari, Mado, cheat sheet, 船 Fune, 蛇 Snake, 読 Yomu) on one screen. Exists only while a panel is open
// there (+ the exit animation). Full-screen transparent layer: clicking outside closes, Esc closes, keyboard focus
// on demand. Created after the bar, so the bar stays on top and keeps working while a panel is open.
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-panel"
    // top normally (the bar keeps working while a panel is open); overlay while 滑 Fluido runs, so Engawa shows over
    // the full-screen video (niri hides the top layer under a full-screen window)
    WlrLayershell.layer: Nameraka.presenting ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // 滑 Fluido: over a full-screen video only the overlay layer shows, and inside it the surface mapped last is on
    // top: when the presenter (re)appears, map this again so it stays above it
    // the host outlives a closed panel: one opened later over Fluido must be mapped above the presenter again
    Connections {
        target: Panels
        function onOpenChanged() {
            if (Nameraka.presenting && Panels.open !== "" && Panels.dragging === "" && win.visible) {
                win.visible = false;
                Qt.callLater(() => win.visible = true);
            }
        }
    }
    Connections {
        target: Nameraka
        function onRemap() {
            if (!win.visible || Panels.dragging !== "")
                return;
            win.visible = false;
            Qt.callLater(() => win.visible = true);
        }
    }

    // the last panel stays loaded while it animates out (and springs back after a short touch drag)
    property string lastKind: ""
    // only the panel opened on THIS screen (広場 lives on the primary one even when another screen has the focus)
    readonly property string which: Panels.open !== "" && Panels.screen === (screen?.name ?? "") ? Panels.open
                                  : Panels.dragging !== "" ? Panels.dragging : lastKind
    onWhichChanged: if (which !== "") lastKind = which
    readonly property bool dragging: Panels.dragging !== ""
    readonly property Item panelItem: panel.item
    property bool entered: false       // false for one frame after creation, so the entrance animates
    readonly property bool shown: entered && (Panels.open !== "" || dragging) && Panels.screen === (screen?.name ?? "")
    signal finished

    onShownChanged: {
        if (shown)
            closeTimer.stop();        // reopened during the exit animation
        else if (entered)
            closeTimer.restart();
    }
    Timer {
        id: closeTimer
        // panels that animate themselves (広場) end with `closed`; this is only the safety net for them
        interval: win.lastKind === "hiroba" ? Motion.hiroba.safety : Motion.d(Motion.fast) + 20
        onTriggered: win.finished()
    }

    // 広場 Hiroba no longer dims the desktop behind it (Ayoub, 2026-10-16): the mockup's .hb-scrim is dropped
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
        onWheel: {}
    }

    FocusScope {
        id: content
        anchors.fill: parent
        focus: true

        // initial focus: a panel that did not place the focus itself gets it on its first control, so the arrows work
        // without a first Tab. Checked once the window has keyboard focus (before that there is no active focus item).
        property bool wantFocus: false
        readonly property Item focused: Window.activeFocusItem
        onFocusedChanged: if (wantFocus) Qt.callLater(initialFocus)
        function inside(it: Item, scope: Item): bool {
            for (let p = it; p; p = p.parent)
                if (p === scope)
                    return true;
            return false;
        }
        function initialFocus(): void {
            const it = panel.item;
            if (!wantFocus || !it)
                return;
            if (focused === null && !Window.active)
                return;                   // retried when the window gets the keyboard
            wantFocus = false;
            if (focused && inside(focused, it))
                return;                   // the panel chose its own focus (a search field, a list…)
            const first = it.nextItemInFocusChain(true);
            if (first && inside(first, it)) {
                Panels.quietFocus = first;
                first.forceActiveFocus();
            }
        }
        Keys.onEscapePressed: {
            if (Panels.page !== "")
                Panels.page = "";
            else
                Panels.close();
        }

        Loader {
            id: panel
            readonly property string kind: win.which
            active: kind !== ""
            // position per panel (docs/02-DISENO §5): Engawa/Fumi right 10 · top 56; Koyomi and Kura centred under
            // the island
            readonly property bool centred: kind === "koyomi" || kind === "kura" || kind === "mihari" || kind === "mado"
                                            || kind === "cheatsheet" || kind === "iro" || kind === "hiroba"
            // 広場 grows out of the island in place and animates itself (Hiroba.qml)
            readonly property bool own: kind === "hiroba"
            // 読 Yomu: next to the region it read (right of it, else left of it, else under it), kept on screen
            readonly property bool beside: kind === "yomu" && Yomu.gw > 0
            readonly property real rx: Yomu.gx - (win.screen?.x ?? 0)
            readonly property real ry: Yomu.gy - (win.screen?.y ?? 0)
            x: beside ? Math.max(10, Math.min(win.width - width - 10,
                                              rx + Yomu.gw + 12 + width <= win.width - 10 ? rx + Yomu.gw + 12
                                              : rx - width - 12 >= 10 ? rx - width - 12 : rx))
             : centred ? (win.width - width) / 2 : win.width - width - 10
            readonly property real topY: own ? Theme.island.hirobaTop
                                       : beside ? Math.max(56, Math.min(win.height - height - 10, ry)) : centred ? 52 : 56
            // while a finger pulls it, the panel follows (from 120 px above, fading in)
            y: own ? topY : win.dragging ? topY - (1 - Panels.dragProgress) * 120 : topY + (win.shown ? 0 : -8)
            opacity: own ? 1 : win.dragging ? Panels.dragProgress : win.shown ? 1 : 0
            Behavior on y { enabled: !win.dragging && !panel.own; Anim { ms: Motion.base; easing.bezierCurve: Motion.decel } }
            Behavior on opacity { enabled: !win.dragging && !panel.own; Anim { ms: win.shown ? Motion.base : Motion.fast } }
            source: kind === "engawa" ? "../engawa/Engawa.qml"
                  : kind === "notifications" ? "../fumi/NotifCenter.qml"
                  : kind === "koyomi" ? "../koyomi/Koyomi.qml"
                  : kind === "hiroba" ? "../hiroba/Hiroba.qml"
                  : kind === "kura" ? "../kura/Kura.qml"
                  : kind === "techo" ? "../techo/Techo.qml"
                  : kind === "mihari" ? "../mihari/Mihari.qml"
                  : kind === "mado" ? "../mado/Mado.qml"
                  : kind === "cheatsheet" ? "../cheatsheet/Cheatsheet.qml"
                  : kind === "iro" ? "../iro/Iro.qml"
                  : kind === "fune" ? "../fune/FunePanel.qml"
                  : kind === "snake" ? "../snake/SnakePanel.qml"
                  : kind === "yomu" ? "../yomu/YomuCard.qml" : ""
            onStatusChanged: if (status === Loader.Error)
                Health.fail("Panel " + kind, Qt.createComponent(source).errorString() || "no se pudo cargar")
            onLoaded: {
                if (own) {
                    item.forceActiveFocus();
                    item.closed.connect(() => { if (!win.shown) win.finished(); });
                } else {
                    content.wantFocus = true;
                    Qt.callLater(content.initialFocus);
                }
            }
            // swallow clicks inside the panel
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }
        }
    }
    Component.onCompleted: {
        content.forceActiveFocus();
        Qt.callLater(() => win.entered = true);
    }
}
