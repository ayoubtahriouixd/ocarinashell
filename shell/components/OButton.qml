import QtQuick
import QtQuick.Layouts
import qs.config

// 30 px button (mock.css .btn): plain, primary (accent) or ghost.
Rectangle {
    id: root
    property string text
    property string icon: ""
    property bool primary: false
    property bool ghost: false
    signal clicked

    implicitHeight: 30
    implicitWidth: row.implicitWidth + 24
    radius: 10
    color: primary ? (area.containsMouse ? Theme.colors.accentPressed : Theme.colors.accent)
         : ghost ? (area.containsMouse ? Theme.colors.surface2 : "transparent")
         : (area.containsMouse ? Theme.colors.surface3 : Theme.colors.surface2)
    border.width: primary ? 0 : 1
    border.color: Theme.colors.outline
    scale: area.pressed ? 0.97 : 1
    opacity: enabled ? 1 : 0.4          // docs/02-DISENO §6: unavailable, no input (MouseArea follows `enabled`)
    Behavior on color { CAnim {} }
    Behavior on scale { Anim { ms: Motion.micro } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        OIcon {
            visible: root.icon !== ""
            icon: root.icon
            size: 16
            color: root.primary ? Theme.colors.accentInk : Theme.colors.text
        }
        OText {
            text: root.text
            size: 12.5
            font.weight: Font.Medium
            color: root.primary ? Theme.colors.accentInk : Theme.colors.text
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Accessible.role: Accessible.Button
    Accessible.name: text
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    FocusRing {}
}
