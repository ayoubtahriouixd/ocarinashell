import QtQuick
import qs.config

// Thin slider (mock.css .hs): 6 px surface3 track, accent fill, 18 px white knob with a 1 px outline. Drag, click,
// wheel and arrow keys. The track is inset by half a knob, so the knob never leaves the control (nor its focus
// ring) at either end (Ayoub, fase 15); a click focuses it for the arrows without drawing the keyboard focus ring.
// `moved(v)` fires live (≤ 30 Hz) for previews; `committed(v)` once at the end of a gesture: persist there (a drag
// must not rewrite settings.json on every pointer event).
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0.05
    property string label: "Control deslizante"
    property string valueText: ""
    readonly property bool dragging: area.pressed
    // shown while dragging; follows `value` otherwise
    property real live: value
    onValueChanged: if (!area.pressed) live = value
    property bool mouseFocus: false           // focused by a click: no keyboard focus ring (FocusRing)
    onActiveFocusChanged: if (!activeFocus) mouseFocus = false
    signal moved(real v)
    signal committed(real v)

    implicitWidth: 220
    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: label + (valueText !== "" ? " " + valueText : "")

    function snap(v: real): real {
        const s = stepSize > 0 ? Math.round((v - from) / stepSize) * stepSize + from : v;
        return Math.max(from, Math.min(to, Number(s.toFixed(4))));
    }
    readonly property real frac: to > from ? (live - from) / (to - from) : 0

    property real pending: NaN
    function setLive(v: real): void {
        const s = snap(v);
        if (s === live)
            return;
        live = s;
        pending = s;
        if (!throttle.running) {
            moved(s);
            pending = NaN;
            throttle.start();
        }
    }
    Timer {
        id: throttle
        interval: 33
        onTriggered: if (!isNaN(root.pending)) { root.moved(root.pending); root.pending = NaN; restart(); }
    }
    function nudge(d: int): void {
        setLive(live + d * stepSize);
        commit.restart();                     // key auto-repeat: one write when the key is released
    }
    Keys.onLeftPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)
    Keys.onDownPressed: nudge(-1)
    Keys.onUpPressed: nudge(1)

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: knob.width / 2
        width: parent.width - knob.width
        height: 6
        radius: 3
        color: Theme.colors.surface3
        Rectangle {
            width: Math.max(height, track.width * root.frac)
            height: parent.height
            radius: 3
            color: Theme.colors.accent
        }
    }
    Rectangle {
        id: knob
        width: 18
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: track.x + track.width * root.frac - width / 2
        color: Theme.colors.knob
        border.width: 1
        border.color: Theme.colors.outlineStrong
        scale: area.pressed ? 1.12 : 1
        Behavior on scale { Anim { ms: Motion.micro } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function at(mx: real): real {
            return root.from + Math.max(0, Math.min(1, (mx - track.x) / track.width)) * (root.to - root.from);
        }
        onPressed: m => { root.mouseFocus = true; root.forceActiveFocus(); root.setLive(at(m.x)); }
        onPositionChanged: m => { if (pressed) root.setLive(at(m.x)); }
        onReleased: root.committed(root.live)
        onWheel: w => {
            root.setLive(root.live + (w.angleDelta.y > 0 || w.angleDelta.x > 0 ? 1 : -1) * root.stepSize);
            commit.restart();
        }
    }
    Timer {
        id: commit
        interval: 400
        onTriggered: root.committed(root.live)
    }
    FocusRing {
        radius: 12
    }
}
