pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · one gauge of the machine as an anime HUD ring: 24 tick marks around, a faint track, the value arc with
// round caps and a soft glow of its colour, the number in the centre; kanji, name and a detail line beside it.
// One sample per second, only while 広場 is open; nothing animates between samples.
HbCard {
    id: root
    property string glyph
    property string name
    property string value: "—"
    property string unit: ""
    property string detail: ""
    property real fraction: 0                 // 0–1
    property color tint: Theme.colors.accent
    // the arc jumps to each sample (1 Hz): an eased arc kept the full-screen panel surface repainting at 120 Hz for a
    // third of every second (measured: 5,9 % CPU with 広場 open → one frame per second)
    readonly property real shown: Math.max(0, Math.min(1, fraction))
    readonly property int lit: Math.ceil(shown * 24)
    implicitHeight: 98

    Item {
        id: ring
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 66
        height: 66
        readonly property real c: width / 2
        readonly property real r: 26

        // 24 ticks; the ones under the value light up in its colour
        Repeater {
            model: 24
            delegate: Rectangle {
                required property int index
                x: ring.c - width / 2
                y: 0
                width: index % 6 === 0 ? 2 : 1.4
                height: index % 6 === 0 ? 5 : 3.5
                radius: 0.7
                color: index < root.lit ? root.tint : Theme.colors.islandTick
                antialiasing: true
                transform: Rotation { origin.x: width / 2; origin.y: ring.c; angle: index * 15 }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {            // track
                strokeColor: Theme.colors.islandTrack
                strokeWidth: 5
                fillColor: "transparent"
                PathAngleArc { centerX: ring.c; centerY: ring.c; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {            // glow
                strokeColor: Theme.alpha(root.tint, 0.22)
                strokeWidth: 12
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc { centerX: ring.c; centerY: ring.c; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: Math.max(0.5, 360 * root.shown) }
            }
            ShapePath {            // value
                strokeColor: root.tint
                strokeWidth: 5
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc { centerX: ring.c; centerY: ring.c; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: Math.max(0.5, 360 * root.shown) }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: -1
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.value
                size: root.value.length > 3 ? 13.5 : root.value.length > 2 ? 15 : 17
                font.weight: Font.Bold
                tabular: true
                color: Theme.colors.islandText
            }
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.unit !== ""
                text: root.unit
                size: 9.5
                color: Theme.colors.islandMuted
                tabular: true
            }
        }
    }
    ColumnLayout {
        anchors.left: ring.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Kanji {
            Layout.alignment: Qt.AlignLeft
            text: root.glyph
            size: 20
            color: root.tint
        }
        OText { Layout.fillWidth: true; text: root.name; size: 12; font.weight: Font.DemiBold; color: Theme.colors.islandText }
        OText { Layout.fillWidth: true; text: root.detail; size: 10; elide: Text.ElideNone; wrapMode: Text.WordWrap; maximumLineCount: 2; color: Theme.colors.islandMuted; tabular: true }
    }
}
