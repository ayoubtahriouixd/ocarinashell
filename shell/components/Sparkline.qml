import QtQuick
import QtQuick.Shapes
import qs.config

// Small history graph: a line plus a soft area under it. `values` are 0…max, oldest first; `count` points span
// the width (the graph fills from the right while history is short). Drawn with QtQuick.Shapes (no Canvas).
Item {
    id: root
    property var values: []
    property real max: 100
    property int count: 60
    property color color: Theme.colors.accent
    property real lineWidth: 1.6

    readonly property var points: {
        const n = values.length, out = [];
        if (n === 0 || width <= 0 || height <= 0)
            return out;
        const step = width / Math.max(1, count - 1);
        const x0 = width - (n - 1) * step;
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, values[i] / Math.max(1e-9, max)));
            out.push(Qt.point(x0 + i * step, height - 1 - v * (height - 2)));
        }
        return out;
    }

    // full-width baseline: a graph that has just started is not an empty box
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.alpha(root.color, 0.25)
    }
    Shape {
        anchors.fill: parent
        visible: root.points.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.alpha(root.color, 0.16)
            startX: root.points.length > 0 ? root.points[0].x : 0
            startY: root.height
            PathPolyline { path: root.points }
            PathLine { x: root.width; y: root.height }
            PathLine { x: root.points.length > 0 ? root.points[0].x : 0; y: root.height }
        }
        ShapePath {
            strokeWidth: root.lineWidth
            strokeColor: root.color
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.points }
        }
    }
}
