import QtQuick
import qs.config
import qs.components
import qs.services

// 蛇 indicator (mockup 11 .ind.snake): 24 px, radius 8, the kanji on text 10 %. Only while the model is loaded (or
// loading / answering: then it breathes). Click, Enter or pull down → the assistant.
Rectangle {
    id: root
    implicitHeight: 24
    implicitWidth: Math.max(24, glyph.implicitWidth + 12)
    radius: Theme.radius.hanko
    color: Theme.alpha(Theme.colors.text, area.containsMouse ? 0.18 : 0.10)
    Behavior on color { CAnim {} }

    Kanji {
        id: glyph
        anchors.centerIn: parent
        text: "蛇"
        size: 13
        color: Theme.colors.text
    }
    SequentialAnimation {
        running: (Snake.starting || Snake.busy) && Motion.enabled
        loops: Animation.Infinite
        onRunningChanged: if (!running) glyph.opacity = 1
        OpacityAnimator { target: glyph; from: 1; to: 0.35; duration: Motion.d(Motion.slow * 2); easing.type: Easing.InOutSine }
        OpacityAnimator { target: glyph; from: 0.35; to: 1; duration: Motion.d(Motion.slow * 2); easing.type: Easing.InOutSine }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4                // a 32 px target (docs/02-DISENO §3) on a 24 px glyph
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("snake", "")
    }
    PullDown {
        panel: "snake"
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Snake: " + (Snake.loaded ? "cargado, " + Snake.name : "cargando")
    Accessible.onPressAction: Panels.toggle("snake", "")
    activeFocusOnTab: true
    Keys.onReturnPressed: Panels.toggle("snake", "")
    Keys.onSpacePressed: Panels.toggle("snake", "")
    FocusRing {}
}
