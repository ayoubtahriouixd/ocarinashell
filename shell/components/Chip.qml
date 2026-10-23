import QtQuick
import QtQuick.Layouts
import qs.config

// 24 px chip (mock.css .chip): optional icon or kanji, text; tone "" | "red" | "asagi" | "ok" | "warn".
Rectangle {
    id: root
    property string kanji: ""
    property string text
    property string tone: ""
    property string icon: ""
    property real iconSize: 15
    property int weight: Font.Medium
    implicitHeight: 24
    implicitWidth: row.implicitWidth + 18
    radius: 12
    readonly property color fg: tone === "red" ? Theme.colors.accent : tone === "asagi" ? Theme.colors.asagi
        : tone === "ok" ? Theme.colors.success : tone === "warn" ? Theme.colors.warning : Theme.colors.textMuted
    // the label of a red chip mixes the accent with the text colour: pure red on its own 16 % tint gave 3:1 (AA wants
    // 4,5 for 11,5 px text; visual QA fase 17). Icons and kanji keep the pure accent (3:1 is enough for glyphs)
    readonly property color labelFg: tone === "red" ? Theme.mix(Theme.colors.accent, Theme.colors.text, Theme.dark ? 0.5 : 0.3) : fg
    color: tone === "" ? Theme.colors.surface2 : Theme.alpha(fg, 0.16)
    border.width: tone === "" ? 1 : 0
    border.color: Theme.colors.outline
    // so a layout can put the chip on a title's baseline (Settei's header)
    baselineOffset: row.y + label.y + label.baselineOffset

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5
        OIcon {
            visible: root.icon !== ""
            icon: root.icon
            size: root.iconSize
            color: root.fg
        }
        Kanji {
            visible: root.kanji !== ""
            text: root.kanji
            size: 12
            color: root.tone === "" ? Theme.colors.text : root.fg
        }
        OText {
            id: label
            text: root.text
            size: 11.5
            font.weight: root.weight
            color: root.labelFg
        }
    }
}
