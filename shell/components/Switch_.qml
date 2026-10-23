import QtQuick
import QtQuick.Window
import qs.config

// Toggle switch, 40 × 24 (mock.css .sw). Off: outlined track and a smaller muted knob; on: accent track and a white
// knob with a ✓ in the accent. Pressing stretches the knob (Material-style); the knob springs to its side.
// Every edge is snapped to whole physical pixels (scale 1,75 would otherwise leave it blurred and off-centre).
Rectangle {
    id: root
    property bool checked: false
    property string label: "Interruptor"
    Accessible.name: label
    signal toggled

    readonly property real dpr: Window.window ? Window.window.devicePixelRatio : 1.75
    function snap(v: real): real {
        return Math.round(v * dpr) / dpr;
    }

    implicitWidth: 40
    implicitHeight: 24
    radius: height / 2
    color: checked ? Theme.colors.accent : Theme.colors.surface3
    border.width: checked ? 0 : snap(1)
    border.color: Theme.colors.outlineStrong
    Behavior on color { CAnim {} }

    readonly property real knobH: snap(checked || area.pressed ? 18 : 14)
    readonly property real knobW: snap(area.pressed ? knobH + 5 : knobH)
    // soft shadow under the white knob (declared first: drawn above the track, below the knob)
    Rectangle {
        visible: root.checked
        x: knob.x
        y: knob.y + root.snap(1)
        width: knob.width
        height: knob.height
        radius: knob.radius
        color: Theme.alpha("#000000", 0.2)
    }
    Rectangle {
        id: knob
        width: root.knobW
        height: root.knobH
        radius: height / 2
        y: root.snap((root.height - height) / 2)
        x: root.snap(root.checked ? root.width - width - (root.height - height) / 2 : (root.height - height) / 2)
        color: root.checked ? Theme.colors.knob : Theme.colors.textMuted
        antialiasing: true
        Behavior on x { enabled: Motion.enabled; SpringAnimation { spring: 5; damping: 0.42; epsilon: 0.05 } }
        Behavior on width { Anim { ms: Motion.micro } }
        Behavior on height { Anim { ms: Motion.micro } }
        Behavior on color { CAnim {} }
        OIcon {
            anchors.centerIn: parent
            visible: root.checked
            icon: "check"
            size: 12
            weight: 700
            color: Theme.colors.accent
            opacity: root.checked ? 1 : 0
            Behavior on opacity { Anim { ms: Motion.fast } }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    activeFocusOnTab: true
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()
    FocusRing {}
}
