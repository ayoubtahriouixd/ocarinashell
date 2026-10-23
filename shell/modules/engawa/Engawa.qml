pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// 縁側 Engawa — control centre (mockup 02). 420 px glass panel, top-right. Detail pages slide in from the right;
// each page lives in its own file loaded by a Loader, so a page whose Quickshell module breaks fails alone.
PanelSurface {
    id: root
    implicitWidth: 420
    implicitHeight: (page === "" ? main.implicitHeight : pageLoader.implicitHeight) + 32
    property string page: Panels.page
    Behavior on implicitHeight { Anim { ms: Motion.base } }

    Component.onCompleted: { Vpn.refresh(); main.refreshUptime(); }

    // keyboard focus across pages: a page takes it on its first control when it loads; going back returns it to the
    // control that opened the page (when that was one of the main page's)
    property Item opener: null
    property Item returnTo: null
    function inside(it: Item, scope: Item): bool {
        for (let p = it; p; p = p.parent)
            if (p === scope)
                return true;
        return false;
    }
    function focusFirst(scope: Item): void {
        if (!scope)
            return;
        const first = scope.nextItemInFocusChain(true);
        if (first && inside(first, scope)) {
            Panels.quietFocus = first;
            first.forceActiveFocus();
        }
    }
    function returnFocus(): void {
        if (!returnTo || !main.visible)
            return;                       // retried when the main page is visible again
        const it = returnTo;
        returnTo = null;
        if (it.visible)
            it.forceActiveFocus();
        else
            focusFirst(main);
    }
    onPageChanged: {
        if (page !== "")
            return;
        returnTo = opener;
        opener = null;
        returnFocus();
    }

    Item {
        anchors.fill: parent
        anchors.margins: 16
        clip: mainSlide.running || pageSlide.running     // clip only while sliding: focus rings must not be cut

        EngawaMain {
            id: main
            width: parent.width
            x: root.page === "" ? 0 : -parent.width - 32
            opacity: root.page === "" ? 1 : 0
            visible: opacity > 0
            Behavior on x { Anim { id: mainSlide; ms: Motion.base } }
            Behavior on opacity { Anim { ms: Motion.fast } }
            onOpenPage: p => {
                const f = root.Window.activeFocusItem;
                root.opener = f && root.inside(f, main) ? f : null;
                Panels.page = p;
            }
            onVisibleChanged: if (visible) root.returnFocus()
        }

        Loader {
            id: pageLoader
            width: parent.width
            active: root.page !== ""
            x: root.page !== "" ? 0 : parent.width + 32
            Behavior on x { Anim { id: pageSlide; ms: Motion.base } }
            source: {
                switch (root.page) {
                case "wifi": return "WifiPage.qml";
                case "bluetooth": return "BtPage.qml";
                case "audio": return "AudioPage.qml";
                case "fluido": return "FluidoPage.qml";
                case "night":
                case "record":
                case "vpn": return "SmallPages.qml";
                default: return "PageUnavailable.qml";
                }
            }
            onLoaded: {
                item.back.connect(() => Panels.page = "");
                Qt.callLater(() => root.focusFirst(pageLoader.item));    // after the page binding has settled
            }
            onStatusChanged: {
                if (status === Loader.Error) {
                    Health.fail("Engawa · " + root.page, "la página no se pudo cargar");
                    source = "PageUnavailable.qml";
                }
            }
        }
        Binding {
            target: pageLoader.item
            property: "page"
            value: root.page
            when: pageLoader.item !== null && pageLoader.item.page !== undefined
        }
    }
}
