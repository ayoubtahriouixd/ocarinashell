import QtQuick
import Quickshell
import Quickshell.Networking

// Sensitive module (Quickshell.Networking) isolated in its own file: if an update breaks it, only Net is
// unavailable (docs/06 capa 3.1). Exposes plain properties for services/Net.qml.
QtObject {
    readonly property bool hasDevices: Networking.devices.values.length > 0
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifi: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi)
                return d;
        return null;
    }
    readonly property var wired: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wired && d.connected)
                return d;
        return null;
    }
    readonly property var network: {
        if (!wifi)
            return null;
        for (const n of wifi.networks.values)
            if (n.connected)
                return n;
        return null;
    }
    readonly property bool connected: (wifi?.connected ?? false) || wired !== null
    readonly property real strength: network?.signalStrength ?? 0
    readonly property string ssid: network?.name ?? ""
    readonly property bool isWired: wired !== null
    function setWifi(on: bool): void {
        Networking.wifiEnabled = on;
    }
}
