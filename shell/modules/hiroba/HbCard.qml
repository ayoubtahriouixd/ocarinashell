import QtQuick
import qs.config
import qs.modules.hiroba
import qs.components

// 広場 card (mock.css .hb-card): white 3,5 % on the island ink, 1 px white 6,5 % border, radius 20. Optional
// label (versalitas with its kanji) at the top-left.
Rectangle {
    id: root
    property string glyph: ""
    property string label: ""
    default property alias content: inner.data
    property real pad: 16
    radius: Theme.island.cardRadius
    color: Theme.colors.islandCard
    border.width: 1
    border.color: Theme.colors.islandLine
    clip: true
    Row {
        id: lbl
        visible: root.label !== ""
        x: root.pad + 2
        y: root.pad
        spacing: 6
        Kanji {
            text: root.glyph
            size: 12
            color: Theme.colors.islandMuted
            anchors.verticalCenter: parent.verticalCenter
        }
        OText {
            text: root.label
            size: 10.5
            font.weight: Font.DemiBold
            font.letterSpacing: 10.5 * 0.12
            font.capitalization: Font.AllUppercase
            color: Theme.colors.islandDim
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
