pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.config
import qs.components
import qs.services

// 設定 Settei — the settings app (docs/02-DISENO §5, mockups 07/10/12): a normal xdg toplevel (niri rule: floating,
// centred, 1240×924, radius 18). Sidebar + one page at a time; every control writes Settings and applies at once.
// Keys: / or Ctrl+F search · Ctrl+Tab / Ctrl+PgDn next page · Ctrl+Shift+Tab / Ctrl+PgUp previous · Esc or Ctrl+W close.
FloatingWindow {
    id: win
    title: Settei.windowTitle
    implicitWidth: 1240
    implicitHeight: 924
    minimumSize: Qt.size(960, 640)
    color: Theme.colors.surface0
    visible: true
    onVisibleChanged: if (!visible) Settei.close()

    readonly property var files: ({
        apariencia: "pages/Apariencia.qml", barra: "pages/Barra.qml", pantalla: "pages/Pantalla.qml",
        sonido: "pages/Sonido.qml", red: "pages/Red.qml", energia: "pages/Energia.qml", shinobi: "pages/Shinobi.qml",
        oni: "pages/Oni.qml", nameraka: "pages/Nameraka.qml", fune: "pages/Fune.qml", snake: "pages/Snake.qml", mamori: "pages/Mamori.qml", bloqueo: "pages/Bloqueo.qml", entrada: "pages/Entrada.qml", atajos: "pages/Atajos.qml",
        notificaciones: "pages/Notificaciones.qml", ventanas: "pages/Ventanas.qml", fondos: "pages/Fondos.qml",
        acerca: "pages/Acerca.qml"
    })

    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Escape || (ctrl && (e.key === Qt.Key_W || e.key === Qt.Key_Q))) {
                Settei.close();
            } else if (e.text === "/" || (ctrl && e.key === Qt.Key_F)) {
                sidebar.searchField.forceActiveFocus();
                sidebar.searchField.selectAll();
            } else if (ctrl && (e.key === Qt.Key_PageDown || e.key === Qt.Key_Tab)) {
                Settei.step(1);
            } else if (ctrl && (e.key === Qt.Key_PageUp || e.key === Qt.Key_Backtab)) {
                Settei.step(-1);
            } else {
                return;
            }
            e.accepted = true;
        }

        Sidebar {
            id: sidebar
            width: 262
            height: parent.height
        }

        Flickable {
            id: flick
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property bool fills: pageLoader.item?.fillsView ?? false
            contentHeight: fills ? height : pageLoader.height + 28 + 34
            interactive: !fills && contentHeight > height
            Component.onCompleted: Settei.flick = flick
            Component.onDestruction: if (Settei.flick === flick) Settei.flick = null

            // Tab into a control outside the view scrolls it in (with a margin); a click never scrolls (the control is
            // already under the pointer, and a slider being dragged must not move away)
            readonly property Item focused: Window.activeFocusItem
            onFocusedChanged: reveal(focused)
            function reveal(it: Item): void {
                if (!it || !interactive || (it.mouseFocus ?? false))
                    return;
                let p = it;
                while (p && p !== contentItem)
                    p = p.parent;
                if (!p)
                    return;                       // the sidebar or a popup: not in the page
                const r = it.mapToItem(contentItem, 0, 0, it.width, it.height);
                if (r.y >= contentY && r.y + r.height <= contentY + height)
                    return;                       // fully visible already
                const margin = 24;
                // taller than the view: show its top
                let y = r.y < contentY || r.height + 2 * margin > height ? r.y - margin : r.y + r.height + margin - height;
                y = Math.max(0, Math.min(contentHeight - height, y));
                if (Motion.enabled) {
                    revealAnim.to = y;
                    revealAnim.restart();
                } else {
                    revealAnim.stop();
                    contentY = y;
                }
            }
            NumberAnimation {
                id: revealAnim
                target: flick
                property: "contentY"
                duration: Motion.d(Motion.fast)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.decel
            }

            Loader {
                id: pageLoader
                x: 34
                y: 28
                width: flick.width - 68
                height: flick.fills ? flick.height - 28 - 28 : (item ? item.implicitHeight : 0)
                source: win.files[Settei.page] ?? "LaterPage.qml"
                asynchronous: true
                opacity: 0
                onLoaded: {
                    flick.contentY = 0;
                    enter.restart();
                }
                onStatusChanged: if (status === Loader.Error) Health.fail("Settei · " + Settei.page, "la página no carga")
                transform: Translate { id: shift; y: 0 }
                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: pageLoader; property: "opacity"; from: 0; to: 1; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
                    NumberAnimation { target: shift; property: "y"; from: 8; to: 0; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
                }
            }
            // a failed page must not leave a blank area
            ColumnLayout {
                visible: pageLoader.status === Loader.Error
                x: 34
                y: 28
                spacing: 8
                OText { text: "Esta página no ha podido cargarse"; size: 18; font.weight: Font.DemiBold }
                OText { text: "El resto de Ajustes sigue funcionando. Mira «ocarina logs» para el detalle."; color: Theme.colors.textMuted }
            }
        }

        // thin scroll indicator (only while the page is longer than the window)
        Rectangle {
            visible: flick.interactive
            anchors.right: parent.right
            anchors.rightMargin: 3
            y: flick.height * flick.visibleArea.yPosition + 4
            width: 4
            height: Math.max(24, flick.height * flick.visibleArea.heightRatio - 8)
            radius: 2
            color: Theme.colors.outlineStrong
            opacity: flick.moving ? 0.9 : 0.45
            Behavior on opacity { Anim { ms: Motion.fast } }
        }
    }
}
