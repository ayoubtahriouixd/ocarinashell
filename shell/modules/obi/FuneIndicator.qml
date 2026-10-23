import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// 船 indicator (mockup 09 .ind.asagi): 24 px, radius 8, asagi kanji on asagi 16 %. Only while the Windows VM is on
// (dimmed while paused; ObiBar loads it only then). Click, Enter or pull down → the Fune panel.
Rectangle {
    id: root
    implicitHeight: 24
    implicitWidth: Math.max(24, glyph.implicitWidth + 12)
    radius: Theme.radius.hanko
    color: Theme.alpha(Theme.colors.asagi, area.containsMouse ? 0.26 : 0.16)
    opacity: Fune.paused ? 0.55 : 1
    Behavior on color { CAnim {} }
    Behavior on opacity { Anim { ms: Motion.fast } }

    Kanji {
        id: glyph
        anchors.centerIn: parent
        text: "船"
        size: 13
        color: Theme.colors.asagi
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4                // a 32 px target (docs/02-DISENO §3) on a 24 px glyph
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("fune", "")
    }
    PullDown {
        panel: "fune"
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Windows: " + Fune.label
    Accessible.onPressAction: Panels.toggle("fune", "")
    activeFocusOnTab: true
    Keys.onReturnPressed: Panels.toggle("fune", "")
    Keys.onSpacePressed: Panels.toggle("fune", "")
    FocusRing {}
}
