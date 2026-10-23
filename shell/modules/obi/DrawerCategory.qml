import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A category in the drawer's rail: kanji box (the red hanko with its glow when selected, like Settei's NavItem),
// label and how many apps it holds.
Rectangle {
    id: root
    required property string kanji
    required property string label
    property int count: 0
    property bool selected: false
    signal activated

    implicitHeight: 36
    radius: Theme.radius.control + 1
    color: selected ? Theme.colors.surface2 : area.containsMouse ? Theme.alpha(Theme.colors.surface2, 0.6) : "transparent"
    opacity: count === 0 && !selected ? 0.45 : 1
    Behavior on color { CAnim { ms: Motion.fast } }
    Accessible.role: Accessible.PageTab
    Accessible.name: label + ", " + count
    Accessible.selected: selected

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 10
        spacing: 10
        Item {
            implicitWidth: 24
            implicitHeight: 24
            Rectangle {
                visible: root.selected
                anchors.fill: box
                anchors.margins: -3
                anchors.topMargin: -1
                anchors.bottomMargin: -5
                radius: 10
                color: Theme.alpha(Theme.colors.accent, 0.18)
            }
            Rectangle {
                id: box
                anchors.fill: parent
                radius: Theme.radius.hanko
                color: root.selected ? Theme.colors.accent : Theme.colors.surface2
                Behavior on color { CAnim { ms: Motion.fast } }
                Kanji {
                    anchors.centerIn: parent
                    text: root.kanji
                    size: 12.5
                    color: root.selected ? Theme.colors.accentInk : Theme.colors.textMuted
                }
            }
        }
        OText {
            Layout.fillWidth: true
            text: root.label
            size: Theme.font.body
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: root.selected ? Theme.colors.text : Theme.colors.textMuted
        }
        OText {
            text: String(root.count)
            size: Theme.font.caption
            tabular: true
            color: Theme.colors.textDim
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
