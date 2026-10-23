pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// 色 Iro card: big swatch, the three formats (click copies one) and the nearest traditional colour with its kanji,
// reading and ΔE. Esc or a click outside closes it (panel host).
PanelSurface {
    id: root
    implicitWidth: 460
    implicitHeight: col.implicitHeight + 32
    readonly property var p: Iro.picked
    readonly property var near: Iro.near?.color ?? null

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: Theme.radius.card
                color: root.p ? root.p.hex : "transparent"
                border.width: 1
                border.color: Theme.colors.glassBorder
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    spacing: 8
                    Kanji { text: "色"; size: 18; color: Theme.colors.accent }
                    OText { text: "Cuentagotas"; size: 14; font.weight: Font.DemiBold }
                }
                // nearest 伝統色
                RowLayout {
                    visible: root.near !== null
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        radius: 7
                        color: root.near?.hex ?? "transparent"
                        border.width: 1
                        border.color: Theme.colors.glassBorder
                    }
                    Kanji { text: root.near?.kanji ?? ""; size: 22; color: Theme.colors.text }
                    ColumnLayout {
                        spacing: 0
                        OText { text: (root.near?.kana ?? "") + " · " + (root.near?.id ?? ""); size: 11.5; font.family: Theme.font.jp; color: Theme.colors.textMuted }
                        OText { text: root.near?.es ?? ""; size: 12.5 }
                    }
                }
                OText {
                    visible: root.near !== null
                    text: "近い色 · " + (root.near?.hex ?? "") + " · ΔE " + (Iro.near?.distance ?? 0).toFixed(3).replace(".", ",")
                        + ((Iro.near?.distance ?? 1) < 0.02 ? " (casi idéntico)" : "")
                    size: 11.5
                    tabular: true
                    color: Theme.colors.textMuted
                }
            }
        }

        Repeater {
            model: root.p ? [{ k: "HEX", v: root.p.hex }, { k: "RGB", v: root.p.rgb }, { k: "OKLCH", v: root.p.oklch }]
                          .concat(root.near ? [{ k: "伝統色", v: root.near.kanji + " " + root.near.hex }] : []) : []
            delegate: Rectangle {
                id: fmt
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.radius.control
                color: hov.hovered ? Theme.colors.surface2 : Theme.colors.surface1
                border.width: 1
                border.color: Theme.colors.outline
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10
                    OText { Layout.preferredWidth: 56; text: fmt.modelData.k; size: 11; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.colors.textDim }
                    OText { Layout.fillWidth: true; text: fmt.modelData.v; font.family: Theme.font.mono; size: 13 }
                    OIcon { icon: "content_copy"; size: 16; color: hov.hovered ? Theme.colors.accent : Theme.colors.textMuted }
                }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Iro.copy(fmt.modelData.v.replace(/^\S+ (?=#)/, "")) }
            }
        }
        OText { text: "Clic en un formato para copiarlo · los últimos 12 colores están en 蔵 Kura"; size: 11.5; color: Theme.colors.textMuted }
    }
}
