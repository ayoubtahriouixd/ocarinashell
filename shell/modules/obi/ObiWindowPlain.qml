pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.obi

// 帯 Obi window without compositor blur (fallback when BackgroundEffect is unavailable: glass becomes 94 % opaque).
// The island (島 Shima) lives in the same surface on the primary screen: one window less (each one costs ~25 MB of
// driver memory) and a fixed stacking order. The surface is taller than the bar so the island can grow; the
// exclusive zone stays 40 and the input mask covers only the bar and the island.
PanelWindow {
    id: win

    property bool blurred: false
    property bool island: false
    readonly property real barHeight: Theme.bar.height
    readonly property alias barItem: bar
    // bar.style (Settei → Barra e isla): floating (mockups) · attached (edge to edge, square) · minimal (auto-hide:
    // no exclusive zone; the bar slides away and comes back on the top edge, with a panel open or for the island's
    // OSD/notice/rename)
    readonly property string style: Settings.data.bar.style
    readonly property bool attached: style === "attached"
    readonly property bool minimal: style === "minimal"
    readonly property bool isles: style === "isles"
    // 広場 Hiroba opens under the bar and the island stays (Ayoub, 2026-10-16); tapping the island again closes it
    readonly property bool hirobaShown: island && (Panels.open === "hiroba" || Panels.dragging === "hiroba" || Panels.hirobaClosing)
    readonly property bool islandBusy: shima.item ? ["osd", "peek", "rename"].indexOf(shima.item.mode) >= 0 : false
    property bool touchShown: false
    function touchReveal(): void {
        touchShown = true;
        touchHide.restart();
    }
    Timer {
        id: touchHide
        interval: 4000
        onTriggered: win.touchShown = false
    }
    // ようこそ: once per login the bar comes down from above (Dengen.arriving, only with Motion)
    readonly property bool revealed: !Dengen.arriving && (!minimal || edge.hovered || barHover.hovered || touchShown || Panels.open !== ""
        || Panels.dragging !== "" || islandBusy || Lock.active)
    property bool hiddenFully: minimal && !revealed
    onRevealedChanged: if (revealed) hiddenFully = false; else hideDone.restart()
    Timer {
        id: hideDone
        interval: Motion.d(Motion.base) + 20
        onTriggered: win.hiddenFully = win.minimal && !win.revealed
    }

    WlrLayershell.namespace: "ocarina-obi"
    WlrLayershell.layer: WlrLayer.Top
    // the keyboard only while a workspace name is being edited in the island
    WlrLayershell.keyboardFocus: island && Panels.renameId >= 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true }
    margins { top: attached ? 0 : Theme.bar.top; left: attached ? 0 : Theme.bar.side; right: attached ? 0 : Theme.bar.side }
    implicitHeight: Theme.bar.height + 72
    exclusiveZone: minimal ? 0 : Theme.bar.height
    color: "transparent"
    mask: Region {
        Region { item: win.hiddenFully ? null : (win.isles ? bar.leftCap : bar) }
        Region { item: win.isles && !win.hiddenFully ? bar.rightCap : null }
        Region { item: shima.item && (!win.hiddenFully || win.islandBusy) ? shima.item.hitArea : null }
        Region { item: win.minimal ? edgeStrip : null }
    }
    // minimal: a 4 px strip on the top edge brings the bar back
    Item {
        id: edgeStrip
        width: parent.width
        height: 4
        HoverHandler {
            id: edge
        }
        // touch: a tap or a pull on the top edge shows the bar for a few seconds
        TapHandler {
            acceptedDevices: PointerDevice.TouchScreen
            onTapped: win.touchReveal()
        }
        DragHandler {
            target: null
            acceptedDevices: PointerDevice.TouchScreen
            onActiveChanged: if (active) win.touchReveal()
        }
    }

    // 醒 "Despierto": the inhibitor needs a window; the bar is always there
    LazyLoader {
        id: idleGuard
        active: Idle.inhibit
        source: Qt.resolvedUrl("IdleGuard.qml")
        onItemChanged: if (item) item.window = win
    }

    // the bar draws its own soft shadow (niri's would cover the whole, taller surface)
    SoftShadow {
        target: bar
        visible: !win.attached && !win.isles
        opacity: bar.opacity
        radius: Theme.radius.bar
        offsetY: 8
        blur: 26
        color: Theme.alpha(Theme.colors.shadow, 0.55)
    }

    ObiBar {
        id: bar
        y: win.revealed ? 0 : -(win.barHeight + Theme.bar.top + 4)
        opacity: win.revealed ? 1 : 0
        visible: opacity > 0             // hidden = not rendered: nothing below keeps animating
        Behavior on y { Anim { ms: Motion.base; easing.bezierCurve: win.revealed ? Motion.decel : Motion.accel } }
        Behavior on opacity { Anim { ms: Motion.fast } }
        anchors.left: parent.left
        anchors.right: parent.right
        height: win.barHeight
        square: win.attached
        isles: win.isles
        HoverHandler {
            id: barHover
        }
        screenName: win.screen?.name ?? ""
        glassAlpha: win.blurred && Theme.transparency ? Theme.glassAlpha : Theme.glassOpaqueAlpha
        dpr: win.devicePixelRatio
    }

    // 島 Shima, isolated: if its file breaks, Loader.Error and the bar lives on (docs/06 capa 3.1)
    Loader {
        id: shima
        active: win.island
        source: Qt.resolvedUrl("../shima/Shima.qml")
        x: (win.width - width) / 2
        y: Theme.island.top - Theme.bar.top + (win.attached ? (Theme.bar.height - Theme.island.height) / 2 - (Theme.island.top - Theme.bar.top) : 0)
        opacity: !win.minimal || win.revealed || win.islandBusy ? 1 : 0
        // hidden = not rendered (its equaliser stops), except while a finger pulls 広場 out of it: an invisible item
        // would lose the touch grab
        visible: opacity > 0 || Panels.dragging === "hiroba"
        Behavior on opacity { Anim { ms: Motion.fast } }
        onStatusChanged: {
            if (status === Loader.Ready) {
                Health.ok("Shima");
            } else if (status === Loader.Error) {
                const c = Qt.createComponent(source);      // only to read the real error message
                Health.fail("Shima", c.errorString() || "no se pudo cargar modules/shima/Shima.qml");
            }
        }
    }
    // the island's real rectangle (screen coordinates) for 広場's morph
    Binding { restoreMode: Binding.RestoreNone; when: win.island && shima.item !== null && !win.hirobaShown; target: Panels; property: "islandW"; value: shima.item?.width ?? 210 }
    Binding { restoreMode: Binding.RestoreNone; when: win.island && shima.item !== null && !win.hirobaShown; target: Panels; property: "islandH"; value: shima.item?.height ?? 30 }
    Binding { restoreMode: Binding.RestoreNone; when: win.island && shima.item !== null && !win.hirobaShown; target: Panels; property: "islandR"; value: shima.item?.hitArea.radius ?? 15 }
    Binding {
        target: shima.item
        property: "dpr"
        value: win.devicePixelRatio
        when: shima.item !== null
    }
}
