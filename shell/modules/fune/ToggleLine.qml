import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A switch row inside a Fune card (mock.css .srow): title 600 13,5 + muted 12,5 line, switch on the right,
// 1 px outline between rows.
Item {
    id: root
    property string title
    property string sub: ""
    property bool checked: false
    property bool separator: false
    signal toggled

    Layout.fillWidth: true
    implicitHeight: Math.max(58, text.implicitHeight + 6)   // .srow: min-height 58, no vertical padding

    Rectangle {
        visible: root.separator
        width: parent.width
        height: 1
        color: Theme.colors.outline
    }
    ColumnLayout {
        id: text
        anchors.left: parent.left
        anchors.right: sw.left
        anchors.leftMargin: 18
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        OText {
            Layout.fillWidth: true
            text: root.title
            size: 14                                // .srow .t b { font: 500 14px }
            font.weight: Font.Medium
        }
        OText {
            Layout.fillWidth: true
            visible: root.sub !== ""
            text: root.sub
            size: Theme.font.small
            color: Theme.colors.textMuted
            wrapMode: Text.Wrap
            elide: Text.ElideNone              // two lines like the mockup, never «…» (OText caps at one line)
            maximumLineCount: 2
        }
    }
    Switch_ {
        id: sw
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        label: root.title
        onToggled: root.toggled()
    }
}
