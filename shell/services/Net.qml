pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Network status for the bar. The Quickshell.Networking part lives in backends/NetBackend.qml, created at run time:
// if it fails to compile after an update, Net.available is false and the bar hides the icon (Health has the error).
Singleton {
    id: root

    property QtObject backend: null
    // no NetworkManager / no devices → hide the icon rather than show a misleading "wifi_off"
    readonly property bool available: backend !== null && (backend?.hasDevices ?? false)
    readonly property bool connected: backend?.connected ?? false
    readonly property bool wired: backend?.isWired ?? false
    readonly property real strength: backend?.strength ?? 0
    readonly property string ssid: backend?.ssid ?? ""
    readonly property string icon: !available ? "" : wired ? "lan"
        : !(backend?.wifiEnabled ?? false) ? "wifi_off" : !connected ? "wifi_find"
        : "wifi"

    function toggleWifi(): void {
        if (backend)
            backend.setWifi(!backend.wifiEnabled);
    }
    // OSD for any change (tile, Fn key / airplane, nmcli), not for the initial value at startup
    readonly property bool wifiOn: backend?.wifiEnabled ?? false
    property bool settled: false
    onWifiOnChanged: if (settled) Osd.show("info", 0, wifiOn ? "Wi-Fi activado" : "Wi-Fi desactivado · 網", wifiOn ? "wifi" : "airplanemode_active")
    Timer { interval: 3000; running: true; onTriggered: root.settled = true }

    Component.onCompleted: {
        const c = Qt.createComponent("backends/NetBackend.qml");
        if (c.status === Component.Ready)
            backend = c.createObject(root);
        else
            Health.fail("Red (Quickshell.Networking)", c.errorString());
    }
}
