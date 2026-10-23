pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Rounded screen corners (optional, appearance.screenCorners): four tiny overlay surfaces, no input, no shadow.
// Each corner is a black square with a transparent rounded rectangle drawn over it via a thick border — the same
// material as every other Rectangle (no Shape/CurveRenderer shader: D-026).
Scope {
    id: root
    required property ShellScreen screen
    readonly property real r: Theme.radius.bar

    Variants {
        model: ["tl", "tr", "bl", "br"]
        delegate: PanelWindow {
            id: corner
            required property string modelData
            screen: root.screen
            WlrLayershell.namespace: "ocarina-corner"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: corner.modelData[0] === "t"
                bottom: corner.modelData[0] === "b"
                left: corner.modelData[1] === "l"
                right: corner.modelData[1] === "r"
            }
            implicitWidth: root.r
            implicitHeight: root.r
            mask: Region {}
            color: "transparent"

            Item {
                anchors.fill: parent
                clip: true
                // a 2r × 2r ring whose inner edge is the rounded corner; only one quarter is inside the surface
                Rectangle {
                    width: root.r * 4
                    height: root.r * 4
                    x: corner.modelData[1] === "l" ? -root.r : -root.r * 2
                    y: corner.modelData[0] === "t" ? -root.r : -root.r * 2
                    radius: root.r * 2
                    color: "transparent"
                    border.width: root.r
                    border.color: "#000000"
                }
            }
        }
    }
}
