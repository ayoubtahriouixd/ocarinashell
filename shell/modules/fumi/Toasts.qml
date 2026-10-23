pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.fumi

// 文 Toast stack (right 14 · top 62, gap 10, max 3 visible + «+N»). The surface exists only while there are
// toasts and is exactly as tall as the stack (input only there). New toasts enter from the right.
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-fumi"
    WlrLayershell.layer: Nameraka.presenting ? WlrLayer.Overlay : WlrLayer.Top     // see PanelHost
    // keyboard only when a toast offers an inline reply (otherwise never steal focus)
    WlrLayershell.keyboardFocus: Notifs.popups.slice(0, 3).some(n => n.hasInlineReply) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 62; right: 0 }
    implicitWidth: 15 + 372 + 14
    implicitHeight: Math.max(1, stack.implicitHeight + 40)
    color: "transparent"
    // 滑 Fluido: over a full-screen video only the overlay layer shows, and inside it the surface mapped last is on
    // top: when the presenter (re)appears, map this again so it stays above it
    property int shownCount: Notifs.popups.length
    property int lastCount: 0
    onShownCountChanged: {
        if (Nameraka.active && win.visible && shownCount > lastCount) {   // a new toast over Fluido: above the presenter
            win.visible = false;
            Qt.callLater(() => win.visible = true);
        }
        lastCount = shownCount;
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
    mask: Region { item: stack }

    ColumnLayout {
        id: stack
        x: 15
        y: 0
        width: 372
        spacing: 10

        Repeater {
            // identity model: a new or dismissed notification does not rebuild the others (timers, typed replies)
            model: ScriptModel {
                values: Notifs.popups.slice(0, 3)
                comparisonMode: ObjectComparison.Identity
            }
            delegate: Toast {
                required property var modelData
                notif: modelData
                Layout.preferredWidth: 372
                opacity: 0
                // the slide lives in the Translate itself, no binding: a transient toast destroyed mid-burst left
                // «x: slide» reading a dead context («Unable to assign [undefined]», 100-notification test, fase 17)
                transform: Translate {
                    id: shift
                    x: 40
                    Behavior on x { Anim { ms: Motion.base; easing.bezierCurve: Motion.decel } }
                }
                Component.onCompleted: { opacity = 1; shift.x = 0; }
                Behavior on opacity { Anim { ms: Motion.base } }
            }
        }
        Chip {
            visible: Notifs.popups.length > 3
            Layout.alignment: Qt.AlignRight
            text: "+" + (Notifs.popups.length - 3) + " más"
            kanji: "文"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.show("notifications", "")
            }
        }
    }
}
