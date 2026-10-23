import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Sensitive module (Quickshell.Bluetooth) isolated in its own file (docs/06 capa 3.1).
QtObject {
    id: backend

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: Bluetooth.devices.values
    readonly property var firstConnected: {
        for (const d of Bluetooth.devices.values)
            if (d.connected)
                return d;
        return null;
    }
    // Ayoub's on/off survives a reboot: BlueZ powers every controller on at boot (AutoEnable), so «off» is an rfkill
    // soft block, which systemd-rfkill saves at shutdown and restores at boot (/dev/rfkill has the session's ACL).
    // persist=false (忍 Shinobi) only powers the adapter down: Shinobi's own state brings it back.
    function setEnabled(on: bool, persist: bool): void {
        if (!adapter)
            return;
        if (on) {
            if (persist !== false) {
                Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
                powerOn.tries = 0;
                powerOn.restart();             // the controller needs a moment after the unblock
            } else {
                adapter.enabled = true;
            }
        } else {
            powerOn.stop();
            adapter.enabled = false;
            if (persist !== false)
                Quickshell.execDetached(["rfkill", "block", "bluetooth"]);
        }
    }
    property Timer powerOn: Timer {
        property int tries: 0
        interval: 250
        repeat: true
        onTriggered: {
            if (backend.adapter?.enabled || ++tries > 12) {
                stop();
                return;
            }
            if (backend.adapter)
                backend.adapter.enabled = true;
        }
    }
    readonly property int connectedCount: {
        let n = 0;
        for (const d of Bluetooth.devices.values)
            if (d.connected)
                n++;
        return n;
    }
}
