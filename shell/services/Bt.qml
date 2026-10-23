pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Bluetooth status for the bar (backend isolated like Net).
Singleton {
    id: root

    property QtObject backend: null
    readonly property bool available: backend !== null && (backend?.present ?? false)
    readonly property bool enabled: backend?.enabled ?? false
    readonly property int connected: backend?.connectedCount ?? 0
    readonly property string summary: {
        const d = backend?.firstConnected;
        if (!d)
            return "";
        return (d.name || d.deviceName) + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + " %" : "")
            + (connected > 1 ? " +" + (connected - 1) : "");
    }
    // your choice (Engawa's tile and page): rfkill block/unblock now + Settings, so the next login applies it again
    function setEnabled(on: bool): void {
        if (!backend)
            return;
        backend.setEnabled(on, true);
        Settings.set("bluetooth.enabled", on);
        Osd.show("info", 0, on ? "Bluetooth activado" : "Bluetooth desactivado", on ? "bluetooth" : "bluetooth_disabled");
    }
    function toggle(): void {
        setEnabled(!enabled);
    }

    // at login: BlueZ (AutoEnable) or a lost rfkill save may have turned it back on; put back what you left. Once, so
    // 忍 Shinobi's temporary power-off and anything you do later are never fought with.
    property bool restored: false
    readonly property bool wantOff: Settings.ready && Settings.data.bluetooth?.enabled === false
    readonly property bool canRestore: !restored && Settings.ready && available
    onCanRestoreChanged: if (canRestore) restoreTimer.start()
    Timer {
        id: restoreTimer
        interval: 1500                      // let BlueZ finish bringing the controller up first
        onTriggered: {
            root.restored = true;
            if (root.wantOff && root.enabled && !Modes.shinobi) {
                root.backend.setEnabled(false, true);
                console.info("Bluetooth: apagado de nuevo al iniciar (lo dejaste apagado)");
            }
        }
    }
    readonly property string icon: !available ? "" : !enabled ? "bluetooth_disabled"
        : connected > 0 ? "bluetooth_connected" : "bluetooth"

    Component.onCompleted: {
        const c = Qt.createComponent("backends/BtBackend.qml");
        if (c.status === Component.Ready)
            backend = c.createObject(root);
        else
            Health.fail("Bluetooth (Quickshell.Bluetooth)", c.errorString());
    }
}
