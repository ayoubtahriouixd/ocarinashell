pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.kagi

// 鍵 Kagi host. Always loaded (an idle WlSessionLock costs nothing) so that unlocking never depends on a Loader being
// torn down in the right order: the session is released only by `locked: false`, which follows Lock.active.
// - real lock: WlSessionLock, one surface per screen (every screen locked; secondaries show only the clock).
// - test mode: the same view on Overlay layers (Esc leaves, auto-unlock at 60 s) — all visual work happens here.
// - dissolve: on success the lock surface plays the burst, an Overlay "ghost" copy maps underneath, the lock is
//   released and the ghost fades (300 ms) into the desktop: no flash of black, no flash of desktop before success.
Scope {
    id: root

    readonly property string primary: {
        for (const s of Quickshell.screens)
            if (Brightness.isInternal(s.name))
                return s.name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }
    WlSessionLock {
        id: session
        locked: Lock.kagiWanted
        onSecureChanged: Lock.reportSecure(secure)
        onLockedChanged: if (!locked) Lock.reportSecure(false)

        WlSessionLockSurface {
            id: surface
            color: Theme.colors.bg

            KagiView {
                id: view
                anchors.fill: parent
                primary: surface.screen !== null && surface.screen.name === root.primary
                interactive: true
                Component.onCompleted: focusInput()
            }
            Connections {
                target: Lock
                function onSucceeded() {
                    if (!Lock.test)
                        view.burst();
                }
            }
        }
    }

    // ------------------------------------------------------------------ real lock → ghost → desktop
    // Lock owns the timing (burst, then release); this only maps the copy and lets it fade once the lock is gone.
    LazyLoader {
        active: Lock.ghost
        Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: ghost
                required property ShellScreen modelData
                screen: modelData
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "ocarina-kagi-ghost"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"
                mask: Region {}
                KagiView {
                    id: ghostView
                    anchors.fill: parent
                    primary: ghost.modelData.name === root.primary
                    interactive: false
                    ghost: true
                    onDissolved: Lock.ghostDone()
                }
                Connections {
                    target: Lock
                    function onActiveChanged() {
                        if (!Lock.active)
                            ghostView.dissolve();
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ test mode
    LazyLoader {
        active: Lock.active && Lock.test
        Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: test
                required property ShellScreen modelData
                readonly property bool isPrimary: modelData.name === root.primary
                screen: modelData
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "ocarina-kagi-test"
                WlrLayershell.keyboardFocus: isPrimary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"           // the view paints its own background, so the dissolve reaches the desktop

                KagiView {
                    id: testView
                    anchors.fill: parent
                    primary: test.isPrimary
                    interactive: true
                    Component.onCompleted: focusInput()
                    onDissolved: Lock.unlocking ? Lock.testDissolved() : Lock.leaveTest()
                    Keys.onEscapePressed: testView.dissolve()
                }
                Connections {
                    target: Lock
                    function onSucceeded() {
                        testView.burst();
                        testFade.restart();
                    }
                }
                Timer {
                    id: testFade
                    interval: Math.max(1, Motion.d(320))
                    onTriggered: testView.dissolve()
                }
            }
        }
    }
}
