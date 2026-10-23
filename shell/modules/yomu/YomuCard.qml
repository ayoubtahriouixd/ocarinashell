pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// 読 Yomu — the card next to the region you read (docs/07-IDEAS.md): what tesseract saw (selectable, already in the
// clipboard), horizontal/vertical and confidence, «Copiar» and «Traducir con Snake»; the translation shows below with
// the reading in hiragana and rōmaji. Closing it deletes the capture.
PanelSurface {
    id: root
    implicitWidth: 380
    alpha: Theme.glassOpaqueAlpha              // no compositor blur behind it (PanelHostBlur)
    implicitHeight: col.implicitHeight + 32

    Component.onDestruction: Yomu.closed()

    ColumnLayout {
        id: col
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: Theme.radius.control + 1
                color: Theme.colors.accentSoft
                Kanji {
                    anchors.centerIn: parent
                    text: "読"
                    size: 18
                    color: Theme.colors.accent
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                OText {
                    text: "Yomu · leer"
                    size: Theme.font.title
                    font.weight: Font.DemiBold
                }
                OText {
                    Layout.fillWidth: true
                    text: Yomu.error !== "" ? "sin texto"
                        : Yomu.result ? (Yomu.result.vertical ? "japonés vertical" : Yomu.result.japanese ? "japonés" : "texto")
                                        + " · confianza " + Math.round(Yomu.result.confidence) + " % · copiado"
                        : "leyendo…"
                    size: Theme.font.small
                    color: Theme.colors.textMuted
                }
            }
            IconButton {
                icon: "close"
                label: "Cerrar"
                onClicked: Panels.close()
            }
        }

        OText {
            visible: Yomu.error !== ""
            Layout.fillWidth: true
            text: Yomu.error
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.colors.textMuted
        }

        // what was read (selectable)
        Rectangle {
            visible: (Yomu.result?.text ?? "") !== ""
            Layout.fillWidth: true
            implicitHeight: Math.min(220, ocr.implicitHeight + 20)
            radius: Theme.radius.card - 4
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline
            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                contentHeight: ocr.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: ocr
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    text: Yomu.result?.text ?? ""
                    color: Theme.colors.text
                    selectionColor: Theme.alpha(Theme.colors.accent, 0.35)
                    font.family: Settings.data.appearance.jpFont
                    font.pointSize: 15 * 0.75 * Theme.font.scale
                }
            }
        }

        RowLayout {
            visible: (Yomu.result?.text ?? "") !== ""
            spacing: 6
            OButton {
                text: Yomu.translating ? "Traduciendo…" : Yomu.translation ? "Traducir otra vez" : "Traducir con Snake"
                icon: "translate"
                primary: Yomu.translation === null
                enabled: !Yomu.translating
                onClicked: Yomu.translate()
            }
            OButton {
                text: "Copiar"
                icon: "content_copy"
                onClicked: Yomu.copy(Yomu.result.text)
            }
        }

        OText {
            visible: Yomu.translating && Yomu.trPartial !== ""
            Layout.fillWidth: true
            text: Yomu.trPartial
            textFormat: Text.PlainText
            size: Theme.font.title - 1
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            maximumLineCount: 12
        }
        OText {
            visible: Yomu.translating
            text: !Snake.loaded ? "Cargando Snake (solo la primera vez, unos segundos)…"
                : Yomu.trPartial !== "" ? "Escribiendo la lectura…" : "Snake está traduciendo…"
            size: Theme.font.small
            color: Theme.colors.textMuted
        }
        OText {
            visible: Yomu.trError !== ""
            Layout.fillWidth: true
            text: Yomu.trError
            textFormat: Text.PlainText
            size: 12
            wrapMode: Text.Wrap
            color: Theme.colors.error
        }

        // the translation
        ColumnLayout {
            visible: Yomu.translation !== null
            Layout.fillWidth: true
            spacing: 6
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.colors.outline }
            OText {
                Layout.fillWidth: true
                text: Yomu.translation?.translation_es ?? ""
                textFormat: Text.PlainText
                size: 14
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 12
            }
            OText {
                visible: (Yomu.translation?.reading_hiragana ?? "") !== ""
                Layout.fillWidth: true
                text: Yomu.translation?.reading_hiragana ?? ""
                textFormat: Text.PlainText
                font.family: Settings.data.appearance.jpFont
                size: 13
                color: Theme.colors.textMuted
                wrapMode: Text.Wrap
                maximumLineCount: 8
            }
            OText {
                visible: (Yomu.translation?.romaji ?? "") !== ""
                Layout.fillWidth: true
                text: Yomu.translation?.romaji ?? ""
                textFormat: Text.PlainText
                size: 12
                font.italic: true
                color: Theme.colors.textDim
                wrapMode: Text.Wrap
                maximumLineCount: 8
            }
            OText {
                visible: (Yomu.translation?.notes ?? "") !== ""
                Layout.fillWidth: true
                text: Yomu.translation?.notes ?? ""
                textFormat: Text.PlainText
                size: 12
                color: Theme.colors.textDim
                wrapMode: Text.Wrap
                maximumLineCount: 4
            }
        }
        OText {
            text: "Local: nada sale de tu equipo; la captura se borra al cerrar."
            size: 11
            color: Theme.colors.textDim
        }
    }
}
