pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · the month (from Koyomi): traditional name in red, kanji weekdays with Sunday in red, 6 weeks, today as a
// glowing hanko. ‹ › (or PgUp/PgDn) move through months; the cells only change with the day or the month.
HbCard {
    id: root
    property int year: Time.now.getFullYear()
    property int month: Time.now.getMonth()
    function shift(d: int): void {
        let mm = month + d, yy = year;
        if (mm < 0) { mm = 11; yy--; }
        if (mm > 11) { mm = 0; yy++; }
        month = mm;
        year = yy;
    }
    readonly property var cells: {
        const k = Time.dayKey;          // recompute when the day changes
        const now = new Date();
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - first.getDay());
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({ day: d.getDate(), inMonth: d.getMonth() === month, sun: d.getDay() === 0,
                       today: d.toDateString() === now.toDateString() });
        }
        return out;
    }

    Screentone {}
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: 12
        spacing: 12
        RowLayout {
            spacing: 10
            Kanji { text: Glossary.month(root.month).wafu; size: 22; color: Theme.colors.accent }
            OText {
                text: Qt.locale("es_ES").standaloneMonthName(root.month) + " " + root.year
                size: 13.5
                font.weight: Font.DemiBold
                color: Theme.colors.islandText
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [{ i: "chevron_left", d: -1, l: "Mes anterior" }, { i: "chevron_right", d: 1, l: "Mes siguiente" }]
                delegate: Rectangle {
                    id: nb
                    required property var modelData
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 11
                    color: na.containsMouse ? Theme.colors.islandTrack : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.l
                    OIcon { anchors.centerIn: parent; icon: nb.modelData.i; size: 20; color: Theme.colors.islandMuted }
                    MouseArea { id: na; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shift(nb.modelData.d) }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 3
            Repeater {
                model: ["日", "月", "火", "水", "木", "金", "土"]
                delegate: Kanji {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    text: modelData
                    size: 12
                    color: index === 0 ? Theme.colors.accent : Theme.colors.islandDim
                }
            }
            Repeater {
                model: root.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 31
                    Rectangle {
                        visible: cell.modelData.today
                        anchors.centerIn: parent
                        width: 36
                        height: 30
                        radius: 9
                        color: Theme.colors.accent
                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.alpha(Theme.colors.accentInk, 0.2)
                        }
                    }
                    OText {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        size: 13
                        tabular: true
                        font.weight: cell.modelData.today ? Font.Bold : Font.Medium
                        color: cell.modelData.today ? Theme.colors.accentInk
                            : !cell.modelData.inMonth ? Theme.colors.islandFaint
                            : cell.modelData.sun ? Theme.colors.accent : Theme.colors.islandText
                    }
                }
            }
        }
    }
}
