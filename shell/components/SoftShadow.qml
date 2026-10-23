import QtQuick

// Soft shadow / glow made of a few concentric rounded rectangles. Same material as every other Rectangle, so it
// adds no shader program (each custom shader costs ~20 MB of driver memory per window on this GPU: measured in
// phase 3). Put it under the item it shadows: SoftShadow { target: pill; color: …; blur: 22; offsetY: 6 }.
Item {
    id: root
    required property Item target
    property color color: Qt.rgba(0, 0, 0, 0.5)
    property real blur: 16
    property real offsetY: 4
    property real radius: target ? (target.radius ?? 0) : 0
    property int steps: 5

    x: target ? target.x : 0
    y: target ? target.y + offsetY : 0
    width: target ? target.width : 0
    height: target ? target.height : 0

    Repeater {
        model: root.steps
        delegate: Rectangle {
            required property int index
            readonly property real grow: root.blur * (index + 1) / root.steps
            x: -grow / 2
            y: -grow / 2
            width: root.width + grow
            height: root.height + grow
            radius: root.radius + grow / 2
            color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.color.a / root.steps * 0.9)
        }
    }
}
