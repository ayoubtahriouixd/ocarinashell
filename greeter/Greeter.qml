pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import "kagi"

// The greeter's window, one per screen (the form only on the main one). Frame 0 is Plymouth's boot splash — background,
// icon 380 Plymouth px centred at 50 % / 42 %, ようこそ 92 px under it — then `settle` (0 → 1) carries the icon up and
// smaller and brings the name, the petal field, the clock and the power buttons in. Leaving after a good password
// is the reverse: everything but the background fades, so the session starts from the same flat colour.
PanelWindow {
    id: win

    property bool main: true
    property var conf: ({})
    property QtObject backend: null
    property string assets: ""
    property bool test: false
    property bool dryRun: false
    signal shown
    signal sessionLaunched
    signal testDone
    Timer {
        id: quitSoon
        interval: 2500
        onTriggered: Qt.quit()
    }

    WlrLayershell.namespace: "ocarina-greeter"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property bool dark: (conf.variant ?? "dark") !== "light"
    readonly property color ink: dark ? Theme.colors.bootInkDark : Theme.colors.bootInkLight
    readonly property color muted: dark ? Theme.colors.bootMutedDark : Theme.colors.bootMutedLight
    color: dark ? Theme.colors.bootDark : Theme.colors.bootLight

    // Plymouth's unit (one pixel of an 1800 px tall panel, in logical px) and its geometry
    readonly property real u: height / 1800
    readonly property real iconA: Math.round(380 * u)
    readonly property real cyA: Math.round(height * 0.42)
    // the form's geometry
    readonly property real iconB: 150
    readonly property real cyB: Math.round(height * 0.29)

    property real settle: 0                       // 0 = Plymouth's frame · 1 = the form
    property real leave: 0                        // 1 = only the background is left
    readonly property real iconSize: iconA + (iconB - iconA) * settle
    readonly property real iconCy: cyA + (cyB - cyA) * settle

    NumberAnimation {
        id: settleAnim
        target: win
        property: "settle"
        to: 1
        duration: Motion.d(Motion.page + 300)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.standard
    }
    NumberAnimation {
        id: leaveAnim
        target: win
        property: "leave"
        to: 1
        duration: Motion.d(Motion.emphasized)
        easing.type: Easing.InOutQuad
        onFinished: win.go()
    }
    Timer {
        // hold Plymouth's frame a beat, so the hand-over reads as one picture that then moves
        id: hold
        interval: Motion.enabled ? 350 : 0
        onTriggered: Motion.enabled ? settleAnim.start() : (win.settle = 1)
    }
    Timer {
        id: shownTimer
        interval: 120                             // a few frames are on screen
        onTriggered: win.shown()
    }
    Component.onCompleted: {
        hold.start();
        shownTimer.start();
        begin();
    }
    // the backend may arrive after this window (shell.qml picks greetd or the test one when it completes)
    property bool begun: false
    onBackendChanged: begin()
    function begin(): void {
        if (begun || !main || !backend)
            return;
        begun = true;
        backend.start(conf.user ?? "ayoub");
    }

    // ── the ocarina (Plymouth's layers) ─────────────────────────────────────────────────────────
    Item {
        id: figure
        opacity: 1 - win.leave
        x: Math.round(win.width / 2 - win.iconSize / 2)
        y: Math.round(win.iconCy - win.iconSize / 2)
        width: win.iconSize
        height: win.iconSize
        BootOcarina {
            anchors.fill: parent
            dir: win.assets
            start: 210
            sourcePx: Math.ceil(win.iconA * win.devicePixelRatio)
        }
    }
    // ようこそ, where Plymouth left it; gone as the form arrives
    Image {
        source: "file://" + win.assets + "/msg-boot-" + (win.dark ? "dark" : "light") + ".png"
        width: Math.round(1200 * win.u)
        height: Math.round(150 * win.u)
        x: Math.round(win.width / 2 - width / 2)
        y: Math.round(win.cyA + win.iconA / 2 + 92 * win.u - height / 2) - 24 * win.settle
        opacity: (1 - Math.min(1, win.settle * 2.2)) * (1 - win.leave)
        visible: opacity > 0
        smooth: true
        mipmap: true
    }

    // ── the form ────────────────────────────────────────────────────────────────────────────────
    Item {
        id: form
        visible: win.main && opacity > 0
        anchors.fill: parent
        opacity: Math.max(0, (win.settle - 0.45) / 0.55) * (1 - win.leave)
        readonly property real drift: (1 - Math.min(1, win.settle)) * 18

        Column {
            id: who
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.cyB + win.iconB / 2 + 26 + form.drift
            spacing: 6
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.conf.name ?? "Ayoub"
                font.family: Theme.font.display
                size: Theme.font.h1
                color: win.ink
            }
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const h = clock.now.getHours();
                    return h < 5 ? "おやすみなさい · Buenas noches" : h < 12 ? "おはよう · Buenos días"
                        : h < 20 ? "こんにちは · Buenas tardes" : "こんばんは · Buenas noches";
                }
                font.family: Theme.font.jp
                size: Theme.font.small
                color: win.muted
            }
        }

        PasswordField {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            y: who.y + who.height + 30
            interactive: win.main && win.leave === 0 && win.prompted
            busy: win.busy
            error: win.failedOnce
            live: Motion.enabled
            onSubmitted: secret => win.submit(secret)
            Keys.onEscapePressed: if (win.test) Qt.quit()
        }
        OText {
            id: hint
            anchors.horizontalCenter: parent.horizontalCenter
            y: field.y + field.height + 16
            text: win.message !== "" ? win.message : win.prompted ? "Intro para entrar" : "Preparando…"
            size: Theme.font.caption
            color: win.failedOnce && win.message !== "" ? Theme.colors.error : win.muted
        }

        // bottom: the clock in the middle, power on the right, keyboard and brand on the left
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            spacing: 2
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.now, "HH:mm")
                size: Theme.font.h3
                tabular: true
                color: win.ink
            }
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.now.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM")
                size: Theme.font.caption
                color: win.muted
            }
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 32; bottomMargin: 36 }
            spacing: 10
            Repeater {
                model: [{ icon: "restart_alt", label: "Reiniciar", cmd: ["systemctl", "reboot"] },
                        { icon: "power_settings_new", label: "Apagar", cmd: ["systemctl", "poweroff"] }]
                delegate: Rectangle {
                    id: pb
                    required property var modelData
                    width: 44
                    height: 44
                    radius: 22
                    activeFocusOnTab: true
                    Keys.onReturnPressed: act()
                    Keys.onEnterPressed: act()
                    Keys.onSpacePressed: act()
                    function act(): void {
                        if (win.test)
                            console.info("greeter (prueba):", modelData.label);
                        else
                            Quickshell.execDetached(modelData.cmd);
                    }
                    color: hover.hovered || activeFocus ? Theme.alpha(win.ink, 0.10) : Theme.alpha(win.ink, 0.05)
                    border.width: 1
                    border.color: Theme.alpha(win.ink, 0.10)
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    OIcon {
                        anchors.centerIn: parent
                        icon: pb.modelData.icon
                        size: 20
                        color: win.ink
                    }
                    HoverHandler { id: hover }
                    TapHandler {
                        onTapped: pb.act()
                    }
                    FocusRing {}
                    OText {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 }
                        visible: hover.hovered || pb.activeFocus
                        text: pb.modelData.label
                        size: Theme.font.caption
                        color: win.muted
                    }
                }
            }
        }
        OText {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 32; bottomMargin: 48 }
            text: "迎 · オカリナシェル" + (win.test ? " · prueba" : "")
            font.family: Theme.font.jp
            size: Theme.font.caption
            color: win.muted
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        readonly property date now: date
    }

    // ── authentication (greetd through the backend) ─────────────────────────────────────────────
    property bool prompted: false                 // PAM asked for the password: the field takes input
    property bool busy: false
    property bool failedOnce: false
    property int greetdErrors: 0
    property string message: ""
    property string pendingSecret: ""

    function submit(secret: string): void {
        if (!backend || busy)
            return;
        busy = true;
        message = "";
        backend.answer(secret);
    }
    function go(): void {
        backend.launch(conf.session ?? ["niri-session"]);
    }
    Connections {
        target: win.main ? win.backend : null
        function onPrompt(message: string, secret: bool) {
            win.greetdErrors = 0;
            win.prompted = true;
            win.busy = false;
            // a non-password question (rare with pam_unix) is shown above the field
            if (!/^pass(word)?:?\s*$/i.test(message.trim()) && !/contraseña/i.test(message))
                win.message = message.trim();
            field.focusInput();
        }
        function onInfo(message: string, error: bool) {
            win.message = message.trim();
        }
        function onFailed(message: string) {
            win.busy = false;
            win.prompted = false;
            win.failedOnce = true;
            win.message = "Contraseña incorrecta";
            field.clear();
            field.shake();
            win.backend.cancel();
            retry.restart();
        }
        // greetd itself failing is not a wrong password: say so, try again, and after 3 in a row leave (exit 1) so
        // greeter-launch falls back to agreety instead of retrying for ever
        function onGreetdError(message: string) {
            win.busy = false;
            win.prompted = false;
            win.greetdErrors++;
            console.warn("greeter: error de greetd", win.greetdErrors, message);
            win.message = "Error del inicio de sesión: " + message.trim();
            field.clear();
            if (win.greetdErrors >= 3) {
                Qt.exit(1);
                return;
            }
            win.backend.cancel();
            retry.restart();
        }
        function onReady() {
            win.busy = false;
            win.greetdErrors = 0;
            win.message = "";
            if (win.dryRun) {                     // probar-greeter.sh: the password was right, nothing starts
                win.message = "✓ Contraseña correcta · prueba terminada";
                win.backend.cancel();
                win.testDone();
                quitSoon.start();
                return;
            }
            if (Motion.enabled)
                leaveAnim.start();
            else {
                win.leave = 1;
                win.go();
            }
        }
        function onLaunched() {
            win.sessionLaunched();
        }
    }
    Timer {
        id: retry
        interval: 900
        onTriggered: win.backend.start(win.conf.user ?? "ayoub")
    }
}
