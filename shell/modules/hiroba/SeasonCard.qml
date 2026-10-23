pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · 七十二候 and the weather: the current microseason in gold brush (reading, translation, days left, 節気),
// then the weather now (kanji, temperature, description, place), the next 3 days and the next 8 hours. Weather comes
// from the Open-Meteo cache (refreshed on open only if it is older than 30 min).
HbCard {
    id: root
    glyph: "七十二候"
    label: "microestación · " + (Kisetsu.sekki.kanji ?? "")
    Component.onCompleted: Weather.refresh()
    Screentone {}
    Kamon {
        visible: Settings.data.hiroba.anime && Settings.data.appearance.kanjiDecor
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        width: 26
        height: 26
    }
    readonly property var now: Weather.info(Weather.code)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        anchors.topMargin: 40
        anchors.bottomMargin: 14
        spacing: 0
        RowLayout {
            spacing: 14
            Kanji {
                text: Kisetsu.ko.kanji ?? ""
                brush: true
                size: 44
                font.weight: Font.Normal
                color: Theme.colors.accent2
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                OText { Layout.fillWidth: true; text: Kisetsu.ko.kana ?? ""; font.family: Theme.font.jp; size: 12; color: Theme.colors.islandMuted }
                OText { Layout.fillWidth: true; text: Kisetsu.ko.es ?? ""; size: 13.5; color: Theme.colors.islandText; wrapMode: Text.WordWrap; maximumLineCount: 2 }
            }
            ColumnLayout {
                spacing: 0
                OText { Layout.alignment: Qt.AlignRight; text: Kisetsu.koDaysLeft; size: 22; font.weight: Font.DemiBold; tabular: true; color: Theme.colors.islandText }
                OText { Layout.alignment: Qt.AlignRight; text: Kisetsu.koDaysLeft === 1 ? "día" : "días"; size: 11; color: Theme.colors.islandDim }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.topMargin: 14; Layout.bottomMargin: 12; implicitHeight: 1; color: Theme.colors.islandSep }
        RowLayout {
            visible: Weather.available
            Layout.fillWidth: true
            spacing: 8
            Kanji { text: root.now.kanji ?? ""; size: 36; color: Theme.colors.islandText }
            OText { text: Math.round(Weather.temperature) + "°"; size: 34; font.weight: Font.Light; tabular: true; color: Theme.colors.islandText }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                OText { Layout.fillWidth: true; text: root.now.es ?? ""; size: 13.5; font.weight: Font.DemiBold; color: Theme.colors.islandText }
                OText { Layout.fillWidth: true; text: Settings.data.weather.place; size: 12; color: Theme.colors.islandMuted }
            }
            Repeater {
                model: Weather.daily
                delegate: ColumnLayout {
                    id: dd
                    required property var modelData
                    spacing: 2
                    Kanji { Layout.alignment: Qt.AlignHCenter; text: Glossary.weekday(new Date(dd.modelData.date + "T12:00").getDay()).kanji; size: 12; color: Theme.colors.islandDim }
                    Kanji { Layout.alignment: Qt.AlignHCenter; text: Weather.info(dd.modelData.code).kanji ?? ""; size: 17; color: Theme.colors.islandText }
                    OText { Layout.alignment: Qt.AlignHCenter; text: Math.round(dd.modelData.max) + "°/" + Math.round(dd.modelData.min) + "°"; size: 11.5; color: Theme.colors.islandMuted; tabular: true }
                }
            }
        }
        Row {
            id: hours
            Layout.fillWidth: true
            Layout.topMargin: 12
            visible: Weather.hoursAhead.length > 0
            Repeater {
                model: Weather.hoursAhead
                delegate: Column {
                    id: hr
                    required property var modelData
                    required property int index
                    width: hours.width / Math.max(1, Weather.hoursAhead.length)      // equal columns
                    spacing: 1
                    OText { anchors.horizontalCenter: parent.horizontalCenter; text: hr.index === 0 ? "ahora" : Time.h24 ? hr.modelData.time : String(parseInt(hr.modelData.time) % 12 || 12); size: 11; color: Theme.colors.islandDim; tabular: true }
                    Kanji { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.info(hr.modelData.code).kanji ?? ""; size: 14; color: hr.index === 0 ? Theme.colors.accent2 : Theme.colors.islandText }
                    OText { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(hr.modelData.temp) + "°"; size: 12; font.weight: Font.DemiBold; color: Theme.colors.islandText; tabular: true }
                }
            }
        }
        OText {
            visible: !Weather.available
            Layout.topMargin: 8
            text: Settings.data.weather.enabled ? "Sin datos del tiempo todavía" : "El tiempo está desactivado en Ajustes"
            size: 12.5
            color: Theme.colors.islandDim
        }
        Item { Layout.fillHeight: true }
    }
}
