import QtQuick
import qs.config

// Decorative kanji (Shippori Mincho B1 by default; `brush: true` for Yuji Syuku).
Text {
    property bool brush: false
    property real size: 15
    color: Theme.colors.text
    font.family: brush ? Theme.font.brush : Theme.font.display
    font.pointSize: size * 0.75 * Theme.font.scale       // appearance.fontScale applies everywhere
    font.weight: Font.Bold      // Shippori Mincho B1 has no 600: Qt picked Medium (too thin vs the mockup)
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
