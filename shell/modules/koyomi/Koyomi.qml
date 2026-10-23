pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// 暦 Koyomi — the living calendar (click on the island). Month with its traditional name, kanji weekdays (Sunday in
// red), today as a hanko; the current 七十二候 (big kanji, reading, translation, days left) and 節気; sunrise/sunset
// and moon phase (local calculation); weather with kanji and 3 days (Open-Meteo, fetched on open if stale);
// world clocks; today's focus blocks ●●○.
PanelSurface {
    id: root
    implicitWidth: body.implicitWidth + 32
    implicitHeight: body.implicitHeight + 32

    property int year: Time.now.getFullYear()
    property int month: Time.now.getMonth()      // shown month (0–11)
    readonly property var m: Glossary.month(month)
    readonly property var weekdays: ["日", "月", "火", "水", "木", "金", "土"]

    Component.onCompleted: {
        Weather.refresh();
        refreshClocks();
    }

    function shift(d: int): void {
        let mm = month + d, yy = year;
        if (mm < 0) { mm = 11; yy--; }
        if (mm > 11) { mm = 0; yy++; }
        month = mm;
        year = yy;
    }
    // 6 weeks × 7 days starting on Sunday (Japanese calendars start on 日)
    // depends on the day (not on every minute of Time.now)
    readonly property var cells: {
        const today = Time.dayKey;
        const now = new Date();
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - first.getDay());
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({ day: d.getDate(), inMonth: d.getMonth() === month, weekday: d.getDay(),
                       today: d.toDateString() === now.toDateString() });
        }
        return out;
    }

    // world clocks (default 東京): `date` with TZ, refreshed on open and on the minute tick, only while visible
    readonly property var clocks: Settings.data.extras.worldClocks.length > 0 ? Settings.data.extras.worldClocks
        : [{ tz: "Asia/Tokyo", kanji: "東京", name: "Tokio" }]
    property var clockTimes: ({})
    function refreshClocks(): void {
        const args = root.clocks.map(c => c.tz);
        clockProc.command = ["sh", "-c", 'for z in "$@"; do printf "%s %s\\n" "$z" "$(TZ=$z date +%H:%M)"; done', "sh"].concat(args);
        clockProc.running = true;
    }
    Process {
        id: clockProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = {};
                for (const l of text.split("\n")) {
                    const [z, hm] = l.split(" ");
                    if (z) t[z] = hm;
                }
                root.clockTimes = t;
            }
        }
    }
    Connections {
        target: Time
        function onMinuteTick() { if (root.visible) root.refreshClocks(); }
    }

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 16
        spacing: 22

        // ── month ────────────────────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Kanji { text: root.m.wafu; size: 26; color: Theme.colors.accent }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    OText { text: root.m.romaji ?? ""; size: 12; color: Theme.colors.textMuted }
                    OText { text: (root.m.es ?? "") + " " + root.year; size: 15; font.weight: Font.DemiBold }
                }
                IconButton { icon: "chevron_left"; label: "Mes anterior"; onClicked: root.shift(-1) }
                IconButton { icon: "chevron_right"; label: "Mes siguiente"; onClicked: root.shift(1) }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2
                Repeater {
                    model: root.weekdays
                    delegate: Kanji {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        text: modelData
                        size: 13
                        color: index === 0 ? Theme.colors.accent : Theme.colors.textMuted
                    }
                }
                Repeater {
                    model: root.cells
                    delegate: Item {
                        id: cell
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        Rectangle {
                            id: hk
                            visible: cell.modelData.today
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: Theme.radius.hanko
                            color: Theme.colors.accent
                        }
                        // rim drawn over the fill (a translucent border on the same Rectangle mixes with the
                        // background, not with the red: grey halo)
                        Rectangle {
                            visible: hk.visible
                            anchors.fill: hk
                            radius: hk.radius
                            color: "transparent"
                            border.width: 1.5
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                        }
                        OText {
                            anchors.centerIn: parent
                            text: cell.modelData.day
                            tabular: true
                            size: 13
                            font.weight: cell.modelData.today ? Font.DemiBold : Font.Normal
                            color: cell.modelData.today ? Theme.colors.accentInk
                                : !cell.modelData.inMonth ? Theme.colors.textDim
                                : cell.modelData.weekday === 0 ? Theme.colors.accent : Theme.colors.text
                            opacity: cell.modelData.inMonth ? 1 : 0.5
                        }
                    }
                }
            }

            // focus blocks of today ●●○
            RowLayout {
                visible: Focus.today.day === Time.dayKey && Focus.today.done > 0 || Focus.active
                spacing: 6
                Kanji { text: "集中"; size: 13; color: Theme.colors.textMuted }
                Repeater {
                    model: Math.min(8, (Focus.today.day === Time.dayKey ? Focus.today.done : 0) + (Focus.active ? 1 : 0))
                    delegate: Rectangle {
                        required property int index
                        width: 9; height: 9; radius: 5
                        readonly property bool running: Focus.active && index === (Focus.today.day === Time.dayKey ? Focus.today.done : 0)
                        color: running ? "transparent" : Theme.colors.accent
                        border.width: 1.5
                        border.color: Theme.colors.accent
                    }
                }
            }
        }

        // ── season, sky, weather, clocks ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            // 七十二候
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: ko.implicitHeight + 24
                radius: Theme.radius.card
                color: Theme.colors.surface1
                border.width: 1
                border.color: Theme.colors.outline
                ColumnLayout {
                    id: ko
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 3
                    OText { text: "七十二候 · microestación"; size: 11.5; color: Theme.colors.textMuted }
                    Kanji {
                        Layout.alignment: Qt.AlignLeft
                        text: Kisetsu.ko.kanji
                        size: 26
                        color: Theme.colors.accent2
                        horizontalAlignment: Text.AlignLeft
                    }
                    OText { text: Kisetsu.ko.kana ?? ""; size: 11.5; font.family: Theme.font.jp; color: Theme.colors.textMuted }
                    OText {
                        Layout.fillWidth: true
                        text: (Kisetsu.ko.es ?? "") + (Kisetsu.koDaysLeft > 0 ? " · quedan " + Kisetsu.koDaysLeft + " días" : "")
                        size: 12.5
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 6
                        Kanji { text: Kisetsu.sekki.kanji ?? ""; size: 14 }
                        OText { text: "節気 · " + (Kisetsu.sekki.es ?? ""); size: 11.5; color: Theme.colors.textMuted }
                    }
                }
            }

            // sun and moon
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                RowLayout {
                    spacing: 5
                    OIcon { icon: "wb_twilight"; size: 16; color: Theme.colors.accent2 }
                    OText { text: Kisetsu.sunriseText + " · " + Kisetsu.sunsetText; size: 12.5; tabular: true }
                }
                RowLayout {
                    spacing: 5
                    Kanji { text: Kisetsu.moon.kanji; size: 13 }
                    OText { text: Kisetsu.moon.es; size: 12; color: Theme.colors.textMuted }
                }
            }

            // weather
            RowLayout {
                Layout.fillWidth: true
                visible: Settings.data.weather.enabled
                spacing: 10
                Kanji {
                    text: Weather.available ? Weather.info(Weather.code).kanji : "—"
                    size: 26
                    color: Theme.colors.text
                }
                ColumnLayout {
                    spacing: 0
                    OText {
                        text: Weather.available ? Math.round(Weather.temperature) + "°  " + Weather.info(Weather.code).es : "Sin datos del tiempo"
                        size: 13
                        font.weight: Font.DemiBold
                    }
                    OText { text: Settings.data.weather.place; size: 11.5; color: Theme.colors.textMuted }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: Weather.daily
                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: 0
                        Kanji {
                            Layout.alignment: Qt.AlignHCenter
                            text: Glossary.weekday(new Date(modelData.date + "T12:00").getDay()).kanji
                            size: 11.5
                            color: Theme.colors.textMuted
                        }
                        Kanji { Layout.alignment: Qt.AlignHCenter; text: Weather.info(modelData.code).kanji; size: 15 }
                        OText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round(modelData.max) + "°/" + Math.round(modelData.min) + "°"
                            size: 11.5
                            tabular: true
                            color: Theme.colors.textMuted
                        }
                    }
                }
            }

            // world clocks
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.clocks
                    delegate: Chip {
                        required property var modelData
                        kanji: modelData.kanji ?? ""
                        text: (modelData.name ?? modelData.tz) + " " + (root.clockTimes[modelData.tz] ?? "—")
                    }
                }
            }
        }
    }
}
