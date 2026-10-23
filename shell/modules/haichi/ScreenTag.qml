pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// 配置 Haichi overlay on one screen:
//  - «Identificar»: its formal numeral (壱 弐 参) huge in the centre for 2 s, with the screen's name and mode;
//  - 発表 presenting: on the copy, an invisible layer above wl-mirror that takes the keyboard on click, so Esc ends
//    the presentation (wl-mirror itself ignores the keyboard), plus a hint for the first seconds.
PanelWindow {
    id: win
    readonly property var info: Displays.byName(screen?.name ?? "")
    readonly property bool presenting: Displays.mirroring && Displays.mirrorTarget === (screen?.name ?? "")
    WlrLayershell.namespace: "ocarina-haichi"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: presenting ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: presenting ? catcher : null }

    Item {
        id: catcher
        anchors.fill: parent
        focus: win.presenting
        Keys.onEscapePressed: Displays.stopMirror()
        MouseArea {
            anchors.fill: parent
            enabled: win.presenting
            onPressed: m => { catcher.forceActiveFocus(); m.accepted = false; }
        }
    }

    Rectangle {
        visible: Displays.identifying
        anchors.centerIn: parent
        width: 360
        height: 340
        radius: 36
        color: Theme.alpha(Theme.colors.surface0, 0.92)
        border.width: 2
        border.color: Theme.colors.accent
        Column {
            anchors.centerIn: parent
            spacing: 6
            Kanji {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Displays.numeralOf(win.screen?.name ?? "")
                size: 190
                color: Theme.colors.accent
            }
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (win.info?.label ?? "") + " · " + (win.screen?.name ?? "")
                size: 18
                font.weight: Font.DemiBold
            }
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.info?.cur ? win.info.cur.w + "×" + win.info.cur.h + " · " + Math.round(win.info.cur.r / 1000) + " Hz · ×" + String(win.info.scale).replace(".", ",") : "apagada"
                size: 13.5
                color: Theme.colors.textMuted
                tabular: true
            }
        }
    }

    Rectangle {
        id: hint
        visible: win.presenting && opacity > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: hintText.implicitWidth + 40
        height: 44
        radius: 22
        color: Theme.colors.island
        opacity: 1
        OText {
            id: hintText
            anchors.centerIn: parent
            text: "発表 Presentando · pulsa aquí y Esc para terminar"
            color: Theme.colors.islandText
            size: 13.5
        }
        Timer {
            running: win.presenting
            interval: 5000
            onTriggered: hint.opacity = 0
        }
        Behavior on opacity { Anim { ms: Motion.slow } }
    }
}
