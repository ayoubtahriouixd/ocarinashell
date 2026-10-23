import QtQuick
import qs.config

// Footer hint: one or more keycaps and what they do, vertically centred on the keycap (mock.css .hint).
Row {
    id: root
    property var keys: []
    property string text
    spacing: 6
    Repeater {
        model: root.keys
        delegate: Kbd {
            required property string modelData
            text: modelData
        }
    }
    OText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        size: 12
        color: Theme.colors.textMuted
    }
}
