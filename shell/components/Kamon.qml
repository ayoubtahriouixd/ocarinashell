pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// 紋 Kamon — the season's crest, drawn (no images, no shaders): 菊 chrysanthemum (autumn, 16 petals, gold),
// 桜 cherry (spring, 5 notched petals, sakura pink), 梅 plum (winter, 5 round petals, white), 葵/波 (summer: 8 petals,
// asagi). The kind follows the month unless `kind` is set. Static: it never animates by itself.
Item {
    id: root
    property string kind: {
        const m = Time.month;          // 0–11
        return m >= 2 && m <= 4 ? "sakura" : m >= 5 && m <= 7 ? "natsu" : m >= 8 && m <= 10 ? "kiku" : "ume";
    }
    property color color: kind === "sakura" ? Theme.colors.sakura : kind === "ume" ? "#f4efe6"
        : kind === "natsu" ? Theme.colors.asagi : Theme.colors.accent2
    property color hole: Theme.colors.island
    implicitWidth: 18
    implicitHeight: 18
    readonly property int n: kind === "kiku" ? 16 : kind === "natsu" ? 8 : 5
    readonly property real s: Math.min(width, height) / 48          // drawn on a 48-unit grid

    Repeater {
        model: root.n
        delegate: Rectangle {
            required property int index
            // a petal: an ellipse standing on the centre, rotated around it
            readonly property real len: (root.kind === "kiku" ? 20 : root.kind === "natsu" ? 17 : 15) * root.s
            readonly property real wid: (root.kind === "kiku" ? 7.2 : root.kind === "natsu" ? 9 : 15) * root.s
            x: root.width / 2 - wid / 2
            y: root.height / 2 - len - (root.kind === "kiku" ? 2 : 1) * root.s
            width: wid
            height: len
            radius: wid / 2
            color: root.color
            opacity: root.kind === "kiku" ? 0.88 : 1
            antialiasing: true
            transform: Rotation {
                origin.x: wid / 2
                origin.y: len + (root.kind === "kiku" ? 2 : 1) * root.s
                angle: index * 360 / root.n
            }
        }
    }
    // sakura: the notch at the tip of each petal
    Repeater {
        model: root.kind === "sakura" ? 5 : 0
        delegate: Rectangle {
            required property int index
            width: 4 * root.s
            height: 4 * root.s
            rotation: 45 + index * 72
            x: root.width / 2 - width / 2 + Math.sin(index * 2 * Math.PI / 5) * 15.5 * root.s
            y: root.height / 2 - height / 2 - Math.cos(index * 2 * Math.PI / 5) * 15.5 * root.s
            color: root.hole
            antialiasing: true
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 12 * root.s
        height: width
        radius: width / 2
        color: root.hole
    }
    Rectangle {
        anchors.centerIn: parent
        width: 8.4 * root.s
        height: width
        radius: width / 2
        color: root.kind === "sakura" || root.kind === "ume" ? Theme.colors.accent2 : root.color
    }
}
