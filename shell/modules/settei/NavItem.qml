import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Sidebar entry (mock.css .nav): 38 px, glyph 26×26 radius 8 in `display` 13.5/600; selected = surface2 row and a
// red hanko glyph with a 1.5 px inner light border and a soft red glow. Optional badge and secondary text.
Rectangle {
    id: root
    property string glyph
    property string text
    property string hint: ""               // search results: the page name, dim, on the right
    property int badge: 0
    property bool selected: false
    property bool later: false              // module of a later phase: text a bit dimmer
    signal activated

    implicitHeight: hint !== "" ? 46 : 38
    radius: 11
    color: selected ? Theme.colors.surface2 : area.containsMouse ? Theme.alpha(Theme.colors.surface2, 0.6) : "transparent"
    Behavior on color { CAnim {} }
    activeFocusOnTab: false
    opacity: later && !selected ? 0.6 : 1
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: selected

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 11
        Item {
            implicitWidth: 26
            implicitHeight: 26
            Rectangle {
                id: glow
                visible: root.selected
                anchors.fill: g
                anchors.margins: -3
                anchors.topMargin: -1
                anchors.bottomMargin: -5
                radius: 11
                color: Theme.alpha(Theme.colors.accent, 0.16)
            }
            Rectangle {
                id: g
                anchors.fill: parent
                radius: 8
                color: root.selected ? Theme.colors.accent : Theme.colors.surface2
                Behavior on color { CAnim {} }
                Rectangle {
                    visible: root.selected
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.alpha(Theme.colors.accentInk, 0.2)
                }
                Kanji {
                    anchors.centerIn: parent
                    text: root.glyph
                    size: 13.5
                    color: root.selected ? Theme.colors.accentInk : Theme.colors.textMuted
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            OText {
                Layout.fillWidth: true
                text: root.text
                size: Theme.font.body
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                color: root.selected ? Theme.colors.text : Theme.colors.textMuted
            }
            OText {
                visible: root.hint !== ""
                Layout.fillWidth: true
                text: root.hint
                size: 11.5
                color: Theme.colors.textDim
            }
        }
        Rectangle {
            visible: root.badge > 0
            implicitHeight: 18
            implicitWidth: Math.max(18, badgeText.implicitWidth + 12)
            radius: 9
            color: Theme.colors.accentSoft
            OText {
                id: badgeText
                anchors.centerIn: parent
                text: String(root.badge)
                size: 10.5
                font.weight: Font.DemiBold
                color: Theme.colors.accent
            }
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
