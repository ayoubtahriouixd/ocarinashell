pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// 鬼 «覚醒» (mockup 08, docs/02-DISENO §Engawa): when Oni starts, a red glow runs along the screen edges for 600 ms,
// once — nothing continuous. Exists only during that moment (ModuleLoader on Modes.kakusei). Overlay layer, no input
// (empty mask), no niri shadow (layer-rules). The glow is the mockup's inset box-shadow (60 px, 38 %) plus a 2 px
// rim (55 %), drawn as a few concentric bordered rectangles (no shader: each one costs ~20 MB on this GPU).
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-kakusei"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}
    color: "transparent"

    Item {
        id: glow
        anchors.fill: parent
        opacity: 0
        Repeater {
            model: 12
            delegate: Rectangle {
                required property int index
                readonly property real inset: index * 5
                x: inset
                y: inset
                width: glow.width - 2 * inset
                height: glow.height - 2 * inset
                color: "transparent"
                border.width: 5
                border.color: Theme.alpha(Theme.colors.oni, 0.38 * Math.pow(1 - index / 12, 1.6))
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: Theme.alpha(Theme.colors.oni, 0.55)
        }
        SequentialAnimation {
            running: true
            OpacityAnimator { target: glow; from: 0; to: 1; duration: Motion.fade(Motion.page * 0.3); easing.type: Easing.OutCubic }
            OpacityAnimator { target: glow; from: 1; to: 0; duration: Motion.fade(Motion.page * 0.7); easing.type: Easing.InCubic }
        }
    }
}
