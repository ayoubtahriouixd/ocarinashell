import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// 新 indicator (mockup 05 .ind.new): 24 px, radius 8, accent2 kanji on accent2 15 %. Only while updates are pending
// or a reboot is waiting (ObiBar loads it only then). Click, Enter: a reboot waiting → Dengen, where «Actualizar y
// reiniciar» is preselected; with 守 Mamori active → its page; without it → `ocarina update` in a terminal.
Rectangle {
    id: root
    implicitHeight: 24
    implicitWidth: Math.max(24, glyph.implicitWidth + 12)
    // «isles»: a pill like the 省 badge beside it (visual QA, fase 14); classic bar: the mockup's 8 px
    radius: Settings.data.bar.style === "isles" ? height / 2 : Theme.radius.hanko
    color: Theme.alpha(Theme.colors.accent2, area.containsMouse ? 0.26 : 0.15)
    Behavior on color { CAnim {} }

    function act(): void {
        if (Updates.mamoriCalls)
            Settei.show("mamori");
        else if (Updates.rebootNeeded)
            Dengen.toggle();
        else if (Mamori.active)
            Settei.show("mamori");
        else
            Quickshell.execDetached(["ghostty", "+new-window", "-e", "sh", "-c", "ocarina update; printf '\\nEnter para cerrar '; read r"]);
    }

    Kanji {
        id: glyph
        anchors.centerIn: parent
        text: "新"
        size: 13
        color: Theme.colors.accent2
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4                // a 32 px target (docs/02-DISENO §3) on a 24 px glyph
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.act()
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Actualizaciones: " + Updates.summary
    Accessible.onPressAction: root.act()
    activeFocusOnTab: true
    Keys.onReturnPressed: root.act()
    Keys.onSpacePressed: root.act()
    FocusRing {}
}
