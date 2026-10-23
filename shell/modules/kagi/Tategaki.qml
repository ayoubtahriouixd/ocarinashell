pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// 縦書き vertical Japanese: one glyph per row, read top to bottom (mockup 03: display 40, tracking .32em).
// Qt has no vertical writing mode; Japanese punctuation would need rotated forms, the proverbs carry none.
Column {
    id: root
    property string text: ""
    property real size: 40
    property color color: Theme.colors.text
    property real tracking: 0.32       // em, added below each glyph

    spacing: size * tracking - size * 0.1

    Repeater {
        model: Array.from(root.text)
        delegate: Text {
            required property string modelData
            width: root.size * 1.1
            height: root.size * 1.1
            text: modelData
            color: root.color
            font.family: Theme.font.display
            font.weight: Font.Medium
            font.pointSize: root.size * 0.75 * Theme.font.scale
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            renderType: Text.CurveRendering
        }
    }
}
