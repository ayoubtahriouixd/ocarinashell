pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.torii

// 鳥居 Torii window, one per screen, created at startup and kept warm: opening is only mapping an already built
// surface (~1 ms here; niri's map + configure adds ~24 ms, D-033). Overlay layer with a 42 % scrim, exclusive keyboard while open.
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-torii"
    WlrLayershell.layer: WlrLayer.Overlay
    // screen name captured once: mapping the surface re-notifies `screen`, which made this binding loop
    property string myScreen: ""
    Component.onCompleted: myScreen = screen?.name ?? ""
    readonly property bool shown: Launcher.open && myScreen !== "" && Launcher.screen === myScreen
    // a hidden (unmapped) surface receives nothing, so focus can stay Exclusive (changing it while mapping looped)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.colors.scrim
    visible: shown

    // set by ToriiWindowBlur when niri blurs behind the panel: only then the glass may be translucent
    property bool blurred: false
    readonly property alias panelItem: panel
    onVisibleChanged: {
        if (!visible)
            return;
        panel.focusInput();
        panel.y = 158;
        panel.opacity = 0;
        enter.restart();
    }

    // first frame after opening: measures the open latency (docs/04-RENDIMIENTO: < 1 frame)
    FrameAnimation {
        id: firstFrame
        running: win.visible
        onTriggered: {
            Launcher.lastOpenMs = Date.now() - Launcher.openedAt;
            stop();
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.hide()
    }

    Torii {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: 150
        alpha: win.blurred && Theme.blur && Theme.transparency
            ? 0.86 : Theme.glassOpaqueAlpha
        MouseArea { anchors.fill: parent; z: -1 }
    }
    // the gate opens: slight drop + fade (decel), first results already there
    ParallelAnimation {
        id: enter
        NumberAnimation { target: panel; property: "y"; to: 150; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Motion.d(Motion.fast) }
    }
}
