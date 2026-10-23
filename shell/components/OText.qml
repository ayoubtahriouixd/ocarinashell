import QtQuick
import qs.config

// UI text: Geist, theme colour, body size. Kanji inside still get JP glyph forms through fontconfig.
Text {
    // size in logical px (fractional allowed); pointSize because pixelSize is an int. Wayland: 96 dpi → 1 pt = 4/3 px
    property real size: Theme.font.body
    property bool tabular: false
    color: Theme.colors.text
    linkColor: Theme.colors.accent
    font.family: Theme.font.ui
    font.pointSize: size * 0.75 * Theme.font.scale       // appearance.fontScale applies everywhere
    font.features: tabular ? { "tnum": 1 } : {}
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1
}
