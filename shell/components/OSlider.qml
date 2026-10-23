import QtQuick
import QtQuick.Layouts
import qs.config

// Thick slider (mock.css .slider): 34 px, surface2 track, `text`-coloured fill with the icon inside, value (and an
// optional device label) on the right; the part of the label under the fill is drawn again in surface0, clipped to
// the fill, so it never disappears. Wheel, drag, click and arrow keys. `moved(v)` only on user input; `released(v)` at
// the end of a drag/click and 400 ms after the last arrow key (auto-repeat commits once). Menu / Shift+F10 = right click.
Item {
    id: root
    property real value: 0               // 0–1
    property string icon: "volume_up"
    property string deviceIcon: ""
    property string deviceLabel: ""
    property bool showValue: true
    property real step: 0.05
    property string valueText: Math.round(value * 100) + " %"   // overridable (e.g. discrete levels)
    property bool shift: false           // Shift held while dragging (multi-screen brightness)
    property string label: ""            // what it controls, for screen readers (else the device label)
    signal moved(real v)
    signal secondary                     // right click or Menu key (e.g. open the device page)
    signal released(real v)              // end of a drag/click: commit expensive changes here

    implicitHeight: 34
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: ([root.label, root.deviceLabel].filter(t => t !== "").join(", ") || "Control deslizante") + " " + valueText

    // user input is coalesced to ≤ 30 Hz (a drag must not spawn a process per pointer event); the last value
    // always goes out
    property real pendingValue: -1
    property real lastValue: 0           // the last value sent by user input (what a key commit releases)
    function set(v: real): void {
        pendingValue = Math.max(0, Math.min(1, v));
        lastValue = pendingValue;
        if (!throttle.running) {
            moved(pendingValue);
            pendingValue = -1;
            throttle.start();
        }
    }
    Timer {
        id: throttle
        interval: 33
        onTriggered: {
            if (root.pendingValue >= 0) {
                root.moved(root.pendingValue);
                root.pendingValue = -1;
                restart();
            }
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 12
        color: Theme.colors.surface2
        clip: true

        Row {
            id: valueRow
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Row {
                visible: root.deviceLabel !== ""
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                OIcon { icon: root.deviceIcon; size: 15; color: Theme.colors.textMuted; visible: root.deviceIcon !== "" }
                OText { text: root.deviceLabel; size: 12; font.weight: Font.Medium; color: Theme.colors.textMuted }
            }
            OText {
                visible: root.showValue
                text: root.valueText
                size: 12
                font.weight: Font.DemiBold
                tabular: true
                color: Theme.colors.textMuted
            }
        }

        Rectangle {
            id: fill
            width: Math.max(radius * 2, track.width * root.value)
            height: parent.height
            radius: 12
            color: Theme.colors.text
            clip: true
            Behavior on width {
                enabled: !drag.active
                Anim { ms: Motion.fast }
            }
            OIcon {
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                icon: root.icon
                fill: true
                size: 18
                color: Theme.colors.surface0
            }
            // inverted copy of the label, visible only where the fill covers it
            Row {
                x: valueRow.x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Row {
                    visible: root.deviceLabel !== ""
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    OIcon { icon: root.deviceIcon; size: 15; color: Theme.colors.surface0; visible: root.deviceIcon !== "" }
                    OText { text: root.deviceLabel; size: 12; font.weight: Font.Medium; color: Theme.colors.surface0 }
                }
                OText {
                    visible: root.showValue
                    text: root.valueText
                    size: 12
                    font.weight: Font.DemiBold
                    tabular: true
                    color: Theme.colors.surface0
                }
            }
        }
    }

    MouseArea {
        id: drag
        property bool active: pressed
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: m => {
            if (m.button === Qt.RightButton) {
                root.secondary();
                return;
            }
            root.shift = (m.modifiers & Qt.ShiftModifier) !== 0;
            root.set(m.x / width);
        }
        onPositionChanged: m => {
            if (pressed && (m.buttons & Qt.LeftButton))
                root.set(m.x / width);
        }
        onReleased: m => {
            root.shift = false;
            if (m.button === Qt.LeftButton)
                root.released(Math.max(0, Math.min(1, m.x / width)));
        }
    }
    WheelStep {
        onStep: dir => root.set(root.value + dir * root.step)
    }
    function nudge(d: int): void {
        // during a burst of keys `value` may still lag behind (it comes back from the service): step from ours
        set((commit.running ? lastValue : value) + d * step);
        commit.restart();
    }
    Timer {
        id: commit
        interval: 400
        onTriggered: root.released(root.lastValue)
    }
    Keys.onLeftPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Menu || (e.key === Qt.Key_F10 && (e.modifiers & Qt.ShiftModifier))) {
            secondary();
            e.accepted = true;
        }
    }
    FocusRing {}
}
