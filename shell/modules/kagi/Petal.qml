import QtQuick
import QtQuick.Shapes
import qs.config

// 花びら one sakura petal (mockup 03: 13 px, viewBox -7…7). Pure Shape, curve-rendered: crisp at any scale.
Shape {
    id: root
    property color color: Theme.colors.sakura
    property real angle: 0
    property real size: 13
    // explicit: Shape's implicit size follows its path bounds, and the path scales with the size (→ collapse to 0)
    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    rotation: angle

    ShapePath {
        strokeWidth: -1
        fillColor: root.color
        // the mockup path, scaled from its 14-unit box to the item and centred
        scale: Qt.size(root.size / 14, root.size / 14)
        startX: 7; startY: 13
        PathCubic { control1X: 4; control1Y: 11; control2X: 2.5; control2Y: 8; x: 3; y: 5 }
        PathCubic { control1X: 3.4; control1Y: 2.2; control2X: 5.4; control2Y: 1.4; x: 6.4; y: 1.8 }
        PathLine { x: 7; y: 2.8 }
        PathLine { x: 7.6; y: 1.8 }
        PathCubic { control1X: 8.6; control1Y: 1.4; control2X: 10.6; control2Y: 2.2; x: 11; y: 5 }
        PathCubic { control1X: 11.5; control1Y: 8; control2X: 10; control2Y: 11; x: 7; y: 13 }
    }
}
