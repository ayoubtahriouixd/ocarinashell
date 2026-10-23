pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// Password field with petals (mockup 03: 392×56, radius 28, glass, hanko → button), shared by Kagi and the polkit
// dialog. The secret lives in an invisible TextInput; what you see are petals: each one lands with a little turn,
// Backspace drops the last one. `keyed(i)` fires on every new character (Kagi's ocarina sounds), `shake()` on a
// wrong password. The owner says when it is busy checking, whether the last try failed and how long to wait.
Item {
    id: root

    property bool interactive: true
    property bool busy: false              // checking: input frozen, «Comprobando…»
    property bool error: false             // last attempt failed: red border
    property double waitUntil: 0           // epoch ms: growing wait after repeated failures
    property bool live: true               // the caret may blink (screen on, motion allowed)
    readonly property alias text: input.text
    signal keyed(int index)
    signal submitted(string secret)

    implicitWidth: 392
    implicitHeight: 56

    function clear(): void {
        input.text = "";
        petals.clear();
    }
    function focusInput(): void {
        input.forceActiveFocus();
    }
    function shake(): void {
        shakeAnim.restart();
    }

    readonly property bool blocked: busy || !interactive || waitLeft > 0
    property int waitLeft: 0
    Timer {
        running: root.waitUntil > Date.now() || root.waitLeft > 0
        interval: 250
        repeat: true
        triggeredOnStart: true
        onTriggered: root.waitLeft = Math.max(0, Math.ceil((root.waitUntil - Date.now()) / 1000))
    }

    TextInput {
        id: input
        // invisible but real: keeps IME, key repeat, Ctrl+Backspace, paste… and never paints the secret
        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.Password
        focus: root.interactive
        enabled: root.interactive
        readOnly: root.blocked
        maximumLength: 256
        Accessible.role: Accessible.EditableText
        Accessible.name: "Contraseña"
        Accessible.passwordEdit: true
        property int last: 0
        onTextChanged: {
            const n = text.length;
            if (n > last) {
                for (let i = last; i < n; i++) {
                    petals.append({ angle: ((i * 37) % 46) - 20 });
                    root.keyed(i);
                }
            } else if (n < last) {
                for (let i = last; i > n; i--) {
                    if (i === n + 1 && n < petals.count)
                        faller.drop(rep.itemAt(n), petals.get(n).angle);
                    petals.remove(petals.count - 1);
                }
            }
            last = n;
        }
        onAccepted: {
            if (text !== "" && !root.blocked) {
                const s = text;
                root.submitted(s);
            }
        }
        Keys.onEscapePressed: event => {
            if (text !== "")
                root.clear();
            else
                event.accepted = false;      // test mode: the window closes
        }
    }

    ListModel { id: petals }

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.colors.surface0, 0.55)
        border.width: 1
        border.color: root.error ? Theme.alpha(Theme.colors.error, 0.55) : "#1fffffff"
        transform: Translate { id: shakeT }
        Behavior on border.color { CAnim { ms: Motion.fast } }
        // inner top highlight (inset 0 1px 0 rgba(255,255,255,.06))
        Rectangle {
            anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 2 * parent.radius
            height: 1
            color: "#0fffffff"
        }

        Item {
            id: well
            anchors { left: parent.left; leftMargin: 22; right: hanko.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: 24
            clip: true

            Row {
                id: row
                spacing: 8
                // the newest petals stay in view: the row slides left once it is wider than the well
                x: Math.min(0, well.width - width - 6)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on x { Anim { ms: Motion.fast } }

                Repeater {
                    id: rep
                    model: petals
                    delegate: Petal {
                        id: petal
                        required property real angle
                        anchors.verticalCenter: parent?.verticalCenter
                        scale: 0
                        opacity: 0
                        rotation: angle - 40
                        Component.onCompleted: land.start()
                        ParallelAnimation {
                            id: land
                            NumberAnimation { target: petal; property: "scale"; to: 1; duration: Motion.d(Motion.base); easing.type: Easing.OutBack; easing.overshoot: Motion.sakugaOvershoot }
                            NumberAnimation { target: petal; property: "opacity"; to: 1; duration: Motion.d(Motion.fast) }
                            NumberAnimation { target: petal; property: "rotation"; to: petal.angle; duration: Motion.d(Motion.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
                        }
                    }
                }
                // caret: accent, 2 × 22 (blinks only while the field can take input and the screen is on)
                Rectangle {
                    id: caret
                    width: 2
                    height: 22
                    radius: 1
                    color: Theme.colors.accent
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: blink.on ? 1 : 0
                }
            }
            // the petal Backspace removed: falls and fades
            Petal {
                id: faller
                visible: false
                function drop(from: Item, a: real): void {
                    if (!from || !Motion.enabled)
                        return;
                    const p = from.mapToItem(well, 0, 0);
                    x = p.x;
                    y = p.y;
                    angle = a;
                    rotation = a;
                    opacity = 1;
                    visible = true;
                    fall.restart();
                }
                ParallelAnimation {
                    id: fall
                    NumberAnimation { target: faller; property: "y"; to: faller.y + 20; duration: Motion.d(Motion.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accel }
                    NumberAnimation { target: faller; property: "rotation"; to: faller.angle + 70; duration: Motion.d(Motion.slow) }
                    NumberAnimation { target: faller; property: "opacity"; to: 0; duration: Motion.d(Motion.slow) }
                    onFinished: faller.visible = false
                }
            }
            OText {
                anchors.verticalCenter: parent.verticalCenter
                x: 18
                visible: input.text === "" && (root.busy || root.waitLeft > 0)
                text: root.busy ? "Comprobando…" : "Espera " + root.waitLeft + " s"
                color: Theme.colors.textMuted
                size: Theme.font.body
            }
        }

        Rectangle {
            id: hanko
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: 40
            height: 40
            radius: 20
            color: hit.pressed ? Theme.colors.accentPressed : Theme.colors.accent
            border.width: 1.5                  // hanko ring: inset 0 0 0 1.5px rgba(255,255,255,.22)
            border.color: "#38ffffff"
            opacity: input.text === "" || root.blocked ? 0.4 : 1
            Behavior on opacity { Anim { ms: Motion.fast } }
            OIcon {
                anchors.centerIn: parent
                icon: root.busy ? "hourglass_top" : "arrow_forward"
                size: 20
                color: Theme.colors.accentInk
            }
            MouseArea {
                id: hit
                anchors.fill: parent
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: input.accepted()
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Desbloquear"
        }
    }

    // a tap anywhere on the field gives it the keyboard back
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 56
        enabled: root.interactive
        onClicked: input.forceActiveFocus()
    }

    Timer {
        id: blink
        property bool on: true
        interval: 530
        repeat: true
        running: root.interactive && input.activeFocus && Motion.enabled && root.live && !root.blocked
        onRunningChanged: on = true
        onTriggered: on = !on
    }

    SequentialAnimation {
        id: shakeAnim
        // 300 ms, decaying (mockup: the whole field trembles with the logo)
        NumberAnimation { target: shakeT; property: "x"; to: 10; duration: Motion.d(40) }
        NumberAnimation { target: shakeT; property: "x"; to: -9; duration: Motion.d(60) }
        NumberAnimation { target: shakeT; property: "x"; to: 6; duration: Motion.d(60) }
        NumberAnimation { target: shakeT; property: "x"; to: -3; duration: Motion.d(60) }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: Motion.d(80) }
    }
}
