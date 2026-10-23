import QtQuick
import qs.config

// 34 × 34 icon button (mock.css .ibtn). `danger` = accent-soft background with accent icon.
Rectangle {
    id: root
    property string icon
    property bool danger: false
    property string label: ""
    signal clicked

    implicitWidth: 34
    implicitHeight: 34
    radius: 11
    color: danger ? Theme.colors.accentSoft : area.containsMouse ? Theme.colors.surface3 : Theme.colors.surface2
    scale: area.pressed ? 0.96 : 1
    Behavior on color { CAnim {} }
    Behavior on scale { Anim { ms: Motion.micro } }

    OIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: 18
        color: root.danger ? Theme.colors.accent : Theme.colors.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Accessible.role: Accessible.Button
    Accessible.name: label || icon
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    FocusRing {}
}
