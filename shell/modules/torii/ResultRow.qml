pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One Torii result (mock.css .res): 56 px, icon 36 (radius 11), title 15/500 with matches in red, subtitle 12.5,
// keys on the right (↵ on the selected row, Ctrl+N on the first nine). Selected = surface2 + glowing red bar.
Item {
    id: root
    required property var item
    required property int index
    readonly property bool selected: index === Launcher.selected
    implicitHeight: 56

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Theme.colors.surface2 : hov.hovered ? Theme.alpha(Theme.colors.surface2, 0.5) : "transparent"
    }
    // red bar with glow on the selected row
    SoftShadow {
        visible: root.selected
        target: bar
        offsetY: 0
        blur: 12
        steps: 3
        color: Theme.alpha(Theme.colors.accent, 0.6)
    }
    Rectangle {
        id: bar
        visible: root.selected
        x: 0
        y: 10
        width: 3
        height: parent.height - 20
        radius: 1.5
        color: Theme.colors.accent
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 11
            readonly property color tint: root.item.tint === "accent" ? Theme.colors.accent
                : root.item.tint === "accent2" ? Theme.colors.accent2 : Theme.colors.text
            color: root.item.iconImage ? Theme.colors.surface3 : Theme.alpha(tint, 0.12)
            IconImage {
                anchors.centerIn: parent
                visible: !!root.item.iconImage
                implicitSize: 26
                source: root.item.iconImage ? (root.item.iconImage.startsWith("/") ? "file://" + root.item.iconImage
                    : Quickshell.iconPath(root.item.iconImage, "application-x-executable")) : ""
                asynchronous: true
            }
            OIcon {
                anchors.centerIn: parent
                visible: !root.item.iconImage && !root.item.glyph
                icon: root.item.icon || "circle"
                fill: true
                size: 20
                color: parent.tint
            }
            OText {
                anchors.centerIn: parent
                visible: !!root.item.glyph
                text: root.item.glyph ?? ""
                // kanji in the mincho face, smaller when it is a 2–3 character word; emoji in colour
                size: root.item.glyphKanji ? [20, 20, 15, 11.5][Math.min(3, (root.item.glyph ?? "").length)] : 20
                font.family: root.item.glyphKanji ? Theme.font.display : Theme.font.emoji + ", " + Theme.font.jp
                font.weight: root.item.glyphKanji ? Font.Bold : Font.Normal
                horizontalAlignment: Text.AlignHCenter
            }
            // 船 Fune badge for Windows apps (phase 12)
            Rectangle {
                visible: !!root.item.badge
                x: parent.width - 12
                y: parent.height - 13
                width: 17
                height: 17
                radius: 5
                color: Theme.colors.asagi
                border.width: 2
                border.color: Theme.colors.surface0
                Kanji { anchors.centerIn: parent; text: root.item.badge ?? ""; size: 10.5; color: Theme.colors.accentInk }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            OText {
                Layout.fillWidth: true
                text: root.item.html
                textFormat: Text.StyledText
                size: 15
                font.weight: Font.Medium
            }
            OText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.item.subtitle ?? ""
                textFormat: Text.PlainText
                size: 12.5
                color: Theme.colors.textMuted
            }
        }
        Row {
            spacing: 4
            Kbd { visible: root.selected; text: "↵" }
            Kbd { visible: !root.selected && root.item.n > 0 && root.item.n <= 9; text: "Ctrl" }
            Kbd { visible: !root.selected && root.item.n > 0 && root.item.n <= 9; text: String(root.item.n) }
        }
    }
    HoverHandler { id: hov }
    TapHandler {
        onTapped: {
            Launcher.selected = root.index;
            Launcher.activate(root.index, false);
        }
    }
}
