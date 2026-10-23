import QtQuick
import qs.config

// Keycap (mock.css .kbd): 22 px, surface1, 1 px outlineStrong border plus a 1 px bottom edge.
Rectangle {
    id: root
    property string text
    implicitWidth: Math.max(22, label.implicitWidth + 12)
    implicitHeight: 22
    radius: 6
    color: Theme.colors.surface1
    border.width: 1
    border.color: Theme.colors.outlineStrong
    // box-shadow 0 1px 0: a rounded copy 1 px lower, behind the key (z < 0 draws under the parent)
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: -1
        radius: parent.radius
        color: Theme.colors.outlineStrong
        z: -1
    }
    OText {
        id: label
        anchors.centerIn: parent
        text: root.text
        size: 11.5
        font.weight: Font.Medium
        color: Theme.colors.textMuted
    }
}
