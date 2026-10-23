import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Health tile (mockup 10 › Salud): icon 18 muted, value 20/600, label 12 muted; card surface1, padding 12/14.
Rectangle {
    id: root
    property string icon
    property string value
    property string label
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: col.implicitHeight + 24
    radius: Theme.radius.card
    color: Theme.colors.surface1
    border.width: 1
    border.color: Theme.colors.outline
    Accessible.role: Accessible.StaticText
    Accessible.name: label + ": " + value

    ColumnLayout {
        id: col
        x: 14
        y: 12
        width: parent.width - 28
        spacing: 0
        OIcon {
            Layout.preferredHeight: 18             // Material Symbols' line box is taller than the glyph
            icon: root.icon
            size: 18
            color: Theme.colors.textMuted
        }
        OText {
            Layout.topMargin: 8
            text: root.value
            size: 20
            lineHeightMode: Text.FixedHeight
            lineHeight: 24                         // 20 × 1.2
            font.weight: Font.DemiBold
            tabular: true
        }
        OText {
            Layout.fillWidth: true
            text: root.label
            size: Theme.font.meta
            lineHeightMode: Text.FixedHeight
            lineHeight: 16.8
            color: Theme.colors.textMuted
            elide: Text.ElideRight
        }
    }
}
