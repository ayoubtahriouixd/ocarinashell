import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Notice on a page whose engine arrives in a later phase: the settings are kept and used from that phase on.
Rectangle {
    id: root
    property string kanji
    property string text
    Layout.fillWidth: true
    Layout.topMargin: 18
    implicitHeight: 52
    radius: 14
    color: Theme.mix(Theme.colors.surface1, Theme.colors.accent, 0.08)
    border.width: 1
    border.color: Theme.alpha(Theme.colors.accent, 0.3)
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12
        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 7
            color: Theme.colors.accent
            Kanji { anchors.centerIn: parent; text: root.kanji; size: 15; color: Theme.colors.accentInk }
        }
        OText { Layout.fillWidth: true; text: root.text; size: 13; wrapMode: Text.WordWrap; maximumLineCount: 2 }
    }
}
