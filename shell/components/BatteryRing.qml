import QtQuick
import Quickshell
import qs.config

// 18 px battery ring (mockup 01: circle r 7.2, stroke 2.2 in an 18 box). Canvas painted at device resolution and
// scaled down (crisp at 1.75×), repainted only when the value or colour changes; no extra shader program.
Item {
    id: root
    property real value: 0          // 0–1
    property color color: Theme.colors.text
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1.75
    implicitWidth: 18
    implicitHeight: 18

    Canvas {
        id: c
        width: root.width * root.dpr
        height: root.height * root.dpr
        scale: 1 / root.dpr
        transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const k = root.dpr, cx = width / 2, cy = height / 2, r = 7.2 * k;
            ctx.lineWidth = 2.2 * k;
            ctx.strokeStyle = Qt.rgba(0.5, 0.5, 0.5, 0.35);
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.stroke();
            const v = Math.max(0, Math.min(1, root.value));
            if (v > 0) {
                ctx.strokeStyle = root.color;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * v);
                ctx.stroke();
            }
        }
    }
    onValueChanged: c.requestPaint()
    onColorChanged: c.requestPaint()
    onDprChanged: c.requestPaint()
}
