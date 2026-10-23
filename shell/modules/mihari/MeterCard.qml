pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One Mihari card: kanji + label, big value, detail line and a history graph (or custom content below).
Rectangle {
    id: root
    property string kanji
    property string label
    property string value
    property string detail
    property var history: []
    property real max: 100
    property color tint: Theme.colors.accent
    property bool graph: true
    default property alias extra: more.data

    implicitHeight: col.implicitHeight + 28
    radius: Theme.radius.card
    color: Theme.colors.surface1
    border.width: 1
    border.color: Theme.colors.outline

    ColumnLayout {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Kanji { text: root.kanji; size: 15; color: root.tint }
            OText { Layout.fillWidth: true; text: root.label; size: 12.5; color: Theme.colors.textMuted; elide: Text.ElideRight }
            OText { text: root.value; size: 17; font.weight: Font.DemiBold; tabular: true }
        }
        OText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.detail
            size: 11.5
            tabular: true
            color: Theme.colors.textMuted
            elide: Text.ElideRight
        }
        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            visible: root.graph
            values: root.history
            max: root.max
            color: root.tint
        }
        Item {
            id: more
            Layout.fillWidth: true
            implicitHeight: childrenRect.height
            visible: children.length > 0
        }
    }
}
