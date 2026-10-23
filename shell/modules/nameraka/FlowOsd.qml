pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// 滑 Fluido OSD and «armando» hint (mockup 13 .shima.osd; docs/02-DISENO «OSD de Fluido», «Isla en armando»): an
// island-shaped surface of its own in the OVERLAY layer (over a full-screen video the bar is hidden: this is the only
// thing of the shell that shows there), mapped after the presenter so it stays above it. 44 px tall, radius 22.
// OSD: hanko 滑 + «×4 · 30 → 120 fps» + «LSFG», 1,2 s. Arming: outlined hanko + «Pon el vídeo a pantalla completa»
// (browsers: «pulsa F o ⛶»; players: a «Pantalla completa» button — the only input it takes).
PanelWindow {
    id: win
    readonly property bool arming: Nameraka.arming
    WlrLayershell.namespace: "ocarina-nameraka-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    margins.top: 9
    implicitWidth: pill.width + 40
    implicitHeight: 44 + 30
    color: "transparent"
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
    mask: Region { item: win.arming && Nameraka.info.player ? fsButton : null }

    SoftShadow {
        target: pill
        color: Qt.rgba(0, 0, 0, 0.45)
        blur: 22
        offsetY: 6
    }
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4
        width: row.implicitWidth + (win.arming ? 18 : 26)
        height: 44
        radius: 22
        color: Theme.colors.island
        border.width: 1
        border.color: Theme.colors.islandBorder
        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 11
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 9
                color: win.arming ? "transparent" : Theme.colors.oni
                border.width: win.arming ? 1.5 : 0
                border.color: Theme.colors.oni
                Kanji {
                    anchors.centerIn: parent
                    text: "滑"
                    font.weight: Font.DemiBold      // .shima .hk: the display face, not the brush
                    size: 18
                    color: win.arming ? Theme.colors.oni : Theme.colors.oniInk
                }
            }
            OText {
                visible: !win.arming
                textFormat: Text.StyledText
                text: !Nameraka.on ? "Nameraka apagado"
                    : "×" + Nameraka.m + " <font color=\"" + Theme.colors.islandMuted + "\">·</font> " + (Nameraka.base > 0 ? Nameraka.fmt(Nameraka.base) + " → " + Math.round(Nameraka.outFps)
                                                                      : "→ " + Nameraka.targetFps) + " fps"
                size: 16
                font.weight: Font.Bold
                tabular: true
                color: Theme.colors.islandText
            }
            OText {
                visible: !win.arming && Nameraka.on
                text: "LSFG"
                size: 13
                font.weight: Font.Medium
                font.family: Theme.font.jp
                color: Theme.colors.islandMuted
            }
            ColumnLayout {
                visible: win.arming
                spacing: 1
                OText { text: "Pon el vídeo a pantalla completa"; size: 13.5; font.weight: Font.DemiBold; color: Theme.colors.islandText }
                OText {
                    visible: !Nameraka.info.player
                    text: "En el navegador: pulsa F o ⛶ en el reproductor"
                    size: 11
                    color: Theme.colors.islandMuted
                }
            }
            Rectangle {
                id: fsButton
                visible: win.arming && Nameraka.info.player === true
                Layout.preferredHeight: 30
                Layout.preferredWidth: fsLabel.implicitWidth + 24
                radius: 15
                color: fsArea.containsMouse ? Theme.colors.islandHover : Theme.colors.islandRest
                OText {
                    id: fsLabel
                    anchors.centerIn: parent
                    text: "Pantalla completa"
                    size: 12.5
                    font.weight: Font.DemiBold
                    color: Theme.colors.islandText
                }
                MouseArea {
                    id: fsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Nameraka.fullscreen()
                }
            }
        }
    }
}
