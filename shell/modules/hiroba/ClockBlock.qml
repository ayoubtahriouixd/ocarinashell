import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · the time: 84/200 tabular clock with the colon in accent, the date in kanji (traditional month in red) and
// in Spanish. Repaints once a minute (Time's tick).
Item {
    id: root
    readonly property string hh: Qt.formatTime(Time.now, Time.h24 ? "HH" : "h")
    readonly property string mm: Qt.formatTime(Time.now, "mm")
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 9
        Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.StyledText
            text: root.hh + "<font color=\"" + Theme.colors.accent + "\">:</font>" + root.mm
            color: Theme.colors.islandText
            font.family: Theme.font.ui
            font.weight: Font.ExtraLight
            font.pointSize: 84 * 0.75 * Theme.font.scale
            font.letterSpacing: -84 * 0.035
            font.features: { "tnum": 1 }
            lineHeightMode: Text.FixedHeight
            lineHeight: 78
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.StyledText
            text: "<font color=\"" + Theme.colors.accent + "\">" + Glossary.month(Time.month).wafu + "</font> · "
                + Glossary.number(Time.dayOfMonth) + "日 · " + Glossary.weekday(Time.weekday).kanji + "曜日"
            color: Theme.colors.islandText
            font.family: Theme.font.display
            font.weight: Font.Bold
            font.pointSize: 16 * 0.75 * Theme.font.scale
            font.letterSpacing: 16 * 0.2
        }
        OText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.locale("es_ES").toString(Time.now, "dddd, d 'de' MMMM 'de' yyyy")
            size: 13
            color: Theme.colors.islandMuted
        }
    }
}
