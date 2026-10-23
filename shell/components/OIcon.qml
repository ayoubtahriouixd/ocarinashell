import QtQuick
import Quickshell
import qs.config
import "glyphs.js" as Glyphs

// Material Symbols Rounded by ligature: OIcon { icon: "wifi"; fill: true }. FILL animates on state changes.
Text {
    id: root
    property string icon: ""
    property bool fill: false
    property real size: Theme.bar.icon
    property int weight: 400
    property real fillAxis: fill ? 1 : 0
    // move glyphs whose ink sits off-centre in the em box (wifi, bluetooth, volume_off…) onto the row's centre line
    property bool optical: false

    text: icon
    color: Theme.colors.text
    font.family: Theme.font.icon
    font.pointSize: size * 0.75 * Theme.font.scale       // appearance.fontScale applies everywhere
    font.variableAxes: { "FILL": root.fillAxis, "wght": root.weight, "GRAD": 0, "opsz": 24 }
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    // NativeRendering: the FILL/wght variable axes are applied (with the distance-field renderer they were not)
    renderType: Text.NativeRendering

    readonly property real dpr: optical ? (QsWindow.window?.devicePixelRatio ?? 1.75) : 1
    transform: Translate {
        x: root.optical ? Glyphs.shiftX(root.icon, root.size * Theme.font.scale, root.dpr) : 0
        y: root.optical ? Glyphs.shiftY(root.icon, root.size * Theme.font.scale, root.dpr) : 0
    }

    Behavior on fillAxis { Anim { ms: Motion.fast } }
}
