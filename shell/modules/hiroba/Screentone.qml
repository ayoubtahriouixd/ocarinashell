import QtQuick
import qs.config
import qs.services

// Manga screentone (mock.css .hb-tone): a corner of halftone dots fading out, painted ONCE per size on a Canvas
// (no per-frame cost). Put it as the last child of a card; it ignores input.
Canvas {
    id: root
    property bool topRight: true
    visible: Settings.data.hiroba.anime && Settings.data.hiroba.screentone
    width: 120
    height: 90
    anchors.top: parent.top
    anchors.right: topRight ? parent.right : undefined
    anchors.left: topRight ? undefined : parent.left
    opacity: 0.5
    renderStrategy: Canvas.Cooperative
    // the island turns paper in the light themes: dots of the other colour
    readonly property bool light: Theme.colors.islandLight
    onLightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const ox = topRight ? width : 0;
        const r = Theme.island.cardRadius;          // the card's corner: no dots outside its curve
        for (let y = 3; y < height; y += 6)
            for (let x = 3; x < width; x += 6) {
                const cx = topRight ? width - r : r;
                if (y < r && (topRight ? x > cx : x < cx) && Math.hypot(x - cx, y - r) > r - 1.5)
                    continue;
                const d = Math.hypot(x - ox, y) / Math.hypot(width, height);
                const a = Math.max(0, 1 - d / 0.75);
                if (a <= 0.02)
                    continue;
                // light dots on the ink, dark ones on the paper island (light themes)
                ctx.fillStyle = Theme.colors.islandLight ? Qt.rgba(0, 0, 0, 0.09 * a) : Qt.rgba(1, 1, 1, 0.13 * a);
                ctx.beginPath();
                ctx.arc(x, y, 1.15, 0, 2 * Math.PI);
                ctx.fill();
            }
    }
}
