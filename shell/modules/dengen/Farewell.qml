pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// さようなら the farewell (fase 13). Dengen → power off / reboot / log out: a full-screen overlay fades to Plymouth's
// background (400 ms) and then shows the icon and the message where the Plymouth shutdown splash draws them, with the
// ocarina playing Plymouth's own loop (components/BootOcarina.qml; the splash takes it up at t = 280). Same layers,
// same geometry (Plymouth pixel units: icon 380 at 1800 high, centre at 50 % / 42 %, message centred 92 below the
// icon), so the hand-over is a cut between the same picture.
// The variant is the one installed for Plymouth (its script says `variant = "…"`), else the theme's light/dark.
// Without Motion (忍 Shinobi, reduced motion) everything is there at once. One per screen; only the farewell's
// lifetime (ModuleLoader on Dengen.leaving).
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-farewell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive     // nothing typed reaches the windows any more
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property string installedDir: "/usr/share/plymouth/themes/ocarinashell"
    readonly property string repoDir: Paths.repo + "/assets/boot/plymouth/ocarinashell"
    property string variant: Theme.dark ? "dark" : "light"
    property string dir: repoDir
    FileView {
        path: win.installedDir + "/ocarinashell.script"
        printErrors: false
        blockLoading: true
        onLoaded: {
            const m = /^variant = "(\w+)";/m.exec(text());
            if (m) {
                win.variant = m[1];
                win.dir = win.installedDir;
            }
        }
    }
    readonly property bool dark: variant !== "light"
    readonly property string kind: Dengen.farewellKind
    // Plymouth's unit: one pixel of a 1800 px tall panel, in this window's logical pixels
    readonly property real u: height / 1800
    readonly property real iconSize: Math.round(380 * u)
    readonly property real cy: Math.round(height * 0.42)
    readonly property real msgY: cy + iconSize / 2 + 92 * u

    // test mode only (`ocarina power farewell …`): Esc leaves; a real farewell cannot be stopped half way
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Dengen.endTest()
    }

    Rectangle {
        id: ground
        anchors.fill: parent
        color: win.dark ? Theme.colors.bootDark : Theme.colors.bootLight
        opacity: 0
        OpacityAnimator {
            id: groundIn
            target: ground
            from: 0
            to: 1
            duration: Motion.d(Motion.farewell)
            easing.type: Easing.InOutQuad
            onFinished: figureIn.start()
        }
    }

    Item {
        id: figure
        anchors.fill: parent
        opacity: 0
        OpacityAnimator {
            id: figureIn
            target: figure
            from: 0
            to: 1
            duration: Motion.d(Motion.slow)
            easing.type: Easing.OutCubic
            onFinished: Dengen.shown()
        }

        // Plymouth's layers, playing its loop from t = 210 (static without Motion); Plymouth's shutdown splash
        // picks the loop up again a moment before a hole sounds (ocarinashell.script: t = 280)
        BootOcarina {
            x: Math.round(win.width / 2 - win.iconSize / 2)
            y: Math.round(win.cy - win.iconSize / 2)
            width: win.iconSize
            height: win.iconSize
            dir: win.dir
            start: 210
            sourcePx: Math.ceil(win.iconSize * win.devicePixelRatio)
        }
        Image {
            visible: win.kind === "shutdown" || win.kind === "reboot"
            source: visible ? "file://" + win.dir + "/msg-" + win.kind + "-" + win.variant + ".png" : ""
            width: Math.round(1200 * win.u)
            height: Math.round(150 * win.u)
            x: Math.round(win.width / 2 - width / 2)
            y: Math.round(win.msgY - height / 2)
            smooth: true
            mipmap: true
        }
        // where Plymouth writes system messages: only while Windows (船 Fune) is shutting down
        OText {
            visible: !Dengen.funeDone
            text: "Apagando Windows…"
            color: win.dark ? Theme.colors.bootNoteDark : Theme.colors.bootNoteLight
            size: Theme.font.body
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(win.height - 90 * win.u - height / 2)
        }
    }

    Component.onCompleted: {
        if (Motion.enabled) {
            groundIn.start();
        } else {
            ground.opacity = 1;
            figure.opacity = 1;
            Qt.callLater(Dengen.shown);
        }
    }
}
