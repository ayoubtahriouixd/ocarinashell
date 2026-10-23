pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.dengen

// 電源 Dengen window (mockup 05): full-screen Overlay on the focused screen, scrim 72 % (+ compositor blur in
// DengenWindowBlur), greeting, five cards, key hints. Keys: L S E R P, ← →, Tab, Enter (hold for the destructive
// ones), Esc. Mouse/touch: tap = run, press and hold = run the destructive ones.
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-dengen"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.alpha("#040305", blurred ? 0.72 : 0.9)
    // 滑 Fluido: over a full-screen video only the overlay layer shows, and inside it the surface mapped last is on
    // top: when the presenter (re)appears, map this again so it stays above it
    Connections {
        target: Nameraka
        function onRemap() {
            if (!win.visible || Panels.dragging !== "")
                return;
            win.visible = false;
            Qt.callLater(() => win.visible = true);
        }
    }

    property bool blurred: false
    readonly property alias cardsItem: cards

    // the one being held (keyboard or pointer) and its progress
    property int holding: -1
    property real hold: 0
    function startHold(i: int): void {
        Dengen.selected = i;
        if (!Dengen.actions[i].destructive) {
            Dengen.run(Dengen.actions[i].id);
            return;
        }
        holding = i;
        hold = 0;
        holdAnim.restart();
    }
    function stopHold(): void {
        holdAnim.stop();
        holding = -1;
        hold = 0;
    }
    NumberAnimation {
        id: holdAnim
        target: win
        property: "hold"
        from: 0
        to: 1
        duration: Dengen.holdMs          // a safety time, not decoration: never scaled by Motion
        onFinished: {
            const i = win.holding;
            win.stopHold();
            if (i >= 0)
                Dengen.run(Dengen.actions[i].id);
        }
    }

    // uptime for the subtitle, read once per opening
    property string uptime: ""
    FileView {
        id: up
        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const s = Math.floor(parseFloat(text().split(" ")[0]) || 0), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
            win.uptime = h > 0 ? h + " h " + m + " min" : m + " min";
        }
    }
    Component.onCompleted: up.reload()

    MouseArea {
        anchors.fill: parent
        onClicked: Dengen.close()
    }

    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -8
        spacing: 0
        opacity: 0
        transform: Translate { id: enterY; y: 8 }
        Component.onCompleted: enter.start()

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Dengen.greeting + "、" + Lock.userName
            color: Theme.colors.text
            font.family: Theme.font.jp
            font.weight: Font.Medium
            font.pointSize: 30 * 0.75 * Theme.font.scale
            lineHeightMode: Text.FixedHeight
            lineHeight: 30
        }
        Item { width: 1; height: 12 }
        OText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Dengen.rebootPending ? "Hay una actualización lista: reiniciar la aplica con un snapshot previo."
                : "Encendido desde hace " + win.uptime + (Power.hasBattery ? " · batería " + Math.round(Power.percent * 100) + " %" : "")
            size: 15
            color: Theme.colors.textMuted
        }
        Item { width: 1; height: 46 }

        Row {
            id: cards
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22
            Repeater {
                model: Dengen.actions
                delegate: DengenCard {
                    id: card
                    required property var modelData
                    required property int index
                    action: modelData
                    selected: Dengen.selected === index
                    hold: win.holding === index ? win.hold : (Dengen.previewHold >= 0 && Dengen.selected === index ? Dengen.previewHold : 0)
                    badge: modelData.id === "reboot" && Dengen.rebootPending
                    onHovered: if (win.holding < 0) Dengen.selected = index
                    onPressedDown: win.startHold(index)
                    onReleased: if (win.holding === index) win.stopHold()
                }
            }
        }
        Item { width: 1; height: 40 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            readonly property var sel: Dengen.actions[Dengen.selected]
            Row {
                spacing: 6
                OText { text: parent.parent.sel.destructive ? "Mantén pulsado" : "Pulsa"; size: 13; color: Theme.colors.textMuted; anchors.verticalCenter: parent.verticalCenter }
                Kbd { text: "↵"; anchors.verticalCenter: parent.verticalCenter }
                OText { text: "para " + parent.parent.sel.verb; size: 13; color: Theme.colors.textMuted; anchors.verticalCenter: parent.verticalCenter }
            }
            OText { text: "·"; size: 13; color: Theme.colors.textMuted }
            Row {
                spacing: 6
                Kbd { text: "←"; anchors.verticalCenter: parent.verticalCenter }
                Kbd { text: "→"; anchors.verticalCenter: parent.verticalCenter }
                OText { text: "elegir"; size: 13; color: Theme.colors.textMuted; anchors.verticalCenter: parent.verticalCenter }
            }
            OText { text: "·"; size: 13; color: Theme.colors.textMuted }
            Row {
                spacing: 6
                Kbd { text: "Esc"; anchors.verticalCenter: parent.verticalCenter }
                OText { text: "cancelar"; size: 13; color: Theme.colors.textMuted; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    ParallelAnimation {
        id: enter
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
        NumberAnimation { target: enterY; property: "y"; to: 0; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
    }

    Item {
        id: keys
        focus: true
        // a release that never arrives (focus lost to polkit, the lock…) must not complete a hold
        onActiveFocusChanged: if (!activeFocus) win.stopHold()
        Keys.onPressed: event => {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            const n = Dengen.actions.length;
            switch (event.key) {
            case Qt.Key_Escape:
                Dengen.close();
                break;
            case Qt.Key_Left:
            case Qt.Key_Backtab:
                win.stopHold();
                Dengen.selected = (Dengen.selected + n - 1) % n;
                break;
            case Qt.Key_Right:
            case Qt.Key_Tab:
                win.stopHold();
                Dengen.selected = (Dengen.selected + 1) % n;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                win.startHold(Dengen.selected);
                break;
            default: {
                const i = Dengen.actions.findIndex(a => a.key === event.text.toUpperCase());
                if (i < 0)
                    return;
                win.startHold(i);
            }
            }
            event.accepted = true;
        }
        // only letting go of the key that started the hold cancels it (not a modifier from the opening chord)
        Keys.onReleased: event => {
            if (event.isAutoRepeat || win.holding < 0)
                return;
            const k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space
                    || event.text.toUpperCase() === Dengen.actions[win.holding].key)
                win.stopHold();
        }
    }
}
