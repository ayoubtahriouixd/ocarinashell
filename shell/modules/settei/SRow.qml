pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Settings row (mock.css .srow): min 58 px, 18 px side padding, title 14/500 + optional subtitle 12.5 textMuted,
// trailing control on the right (default children). 1 px separator above every row but the first of its card.
// A search hit with the same title flashes and scrolls into view (Settei.reveal).
Item {
    id: row
    property string title
    property string sub: ""
    property string leadIcon: ""
    property real titleWidth: 0           // > 0: fixed title column (brightness rows), the trailing part fills
    property real minHeight: 58
    property bool separator: Positioner.index > 0
    property bool dimmed: false           // control not available here (opacity 0.4, no input)
    default property alias trailing: slot.data

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(minHeight, lay.implicitHeight + 16)
    enabled: !dimmed                       // dimmed: the control fades, the text stays readable (it often says why)

    Rectangle {
        visible: row.separator
        width: parent.width
        height: 1
        color: Theme.colors.outline
    }
    Rectangle {
        id: flash
        anchors.fill: parent
        anchors.margins: 2
        radius: 12
        color: Theme.colors.accentSoft
        opacity: 0
        SequentialAnimation {
            id: flashAnim
            Anim { target: flash; property: "opacity"; to: 1; ms: Motion.base }
            PauseAnimation { duration: 900 }
            Anim { target: flash; property: "opacity"; to: 0; ms: Motion.emphasized }
        }
    }
    function reveal(): void {
        const f = Settei.flick;
        if (f) {
            const p = row.mapToItem(f.contentItem, 0, 0);
            f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, p.y - f.height / 3));
        }
        flash.opacity = 0;
        flashAnim.restart();
    }
    Connections {
        target: Settei
        function onReveal(t) { if (t === row.title) row.reveal(); }
    }
    Component.onCompleted: if (Settei.highlight !== "" && Settei.highlight === title) {
        Settei.highlight = "";
        Qt.callLater(row.reveal);
    }

    RowLayout {
        id: lay
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14
        OIcon {
            visible: row.leadIcon !== ""
            icon: row.leadIcon
            size: 22
            color: Theme.colors.textMuted
        }
        ColumnLayout {
            Layout.fillWidth: row.titleWidth <= 0
            Layout.preferredWidth: row.titleWidth > 0 ? row.titleWidth : -1
            spacing: 2
            OText {
                Layout.fillWidth: true
                text: row.title
                size: 14
                font.weight: Font.Medium
                color: row.dimmed ? Theme.colors.textMuted : Theme.colors.text
            }
            OText {
                visible: row.sub !== ""
                Layout.fillWidth: true
                text: row.sub
                size: 12.5
                color: Theme.colors.textMuted
                tabular: true
            }
        }
        RowLayout {
            id: slot
            opacity: row.dimmed ? 0.4 : 1
            Layout.fillWidth: row.titleWidth > 0
            spacing: 10
        }
    }
    Accessible.name: title
}
