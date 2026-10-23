pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// 網 Wi-Fi page. Isolated file (Quickshell.Networking): if the module changes, only this page fails (Loader).
// Scanning runs only while the page is open. Connect (with password if needed), forget, hidden network, share QR.
ColumnLayout {
    id: root
    spacing: 8
    signal back
    property bool embedded: false        // shown inside Settei (Red y Bluetooth / Sonido): no back button

    readonly property var dev: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi)
                return d;
        return null;
    }
    // sorted by state, then signal in 15 % buckets (so a scan does not reorder rows constantly)
    readonly property var networks: {
        if (!dev)
            return [];
        const bucket = n => Math.floor(n.signalStrength * 100 / 15);
        return dev.networks.values.slice().sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known) || (bucket(b) - bucket(a)) || a.name.localeCompare(b.name));
    }
    property var asking: null          // network waiting for a password
    property string message: ""

    Component.onCompleted: if (dev) dev.scannerEnabled = true
    Component.onDestruction: if (dev) dev.scannerEnabled = false

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        kanji: "網"
        hasSwitch: true
        checked: Networking.wifiEnabled
        onBack: root.back()
        showBack: !root.embedded
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    OText {
        visible: root.message !== ""
        Layout.fillWidth: true
        text: root.message
        size: 12
        color: Theme.colors.warning
        wrapMode: Text.WordWrap
        maximumLineCount: 3
    }

    // password prompt
    ColumnLayout {
        visible: root.asking !== null
        Layout.fillWidth: true
        spacing: 6
        OText { text: "Contraseña de «" + (root.asking?.name ?? "") + "»"; size: 12.5; color: Theme.colors.textMuted }
        TextInput_ {
            id: psk
            Layout.fillWidth: true
            password: true
            placeholder: "Contraseña"
            onAccepted: connectBtn.clicked()
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            OButton { text: "Cancelar"; ghost: true; onClicked: { root.asking = null; psk.text = ""; } }
            OButton {
                id: connectBtn
                text: "Conectar"
                primary: true
                onClicked: {
                    const n = root.asking;
                    root.asking = null;
                    n.connectWithPsk(psk.text);
                    psk.text = "";
                }
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2
            Repeater {
                model: ScriptModel {
                    values: root.networks
                    comparisonMode: ObjectComparison.Identity
                }
                delegate: ListRow {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    readonly property real s: modelData.signalStrength
                    icon: s > 0.66 ? "wifi" : s > 0.33 ? "wifi_2_bar" : "wifi_1_bar"
                    title: modelData.name
                    subtitle: modelData.connected ? "Conectada" : modelData.stateChanging ? "Conectando…"
                        : modelData.known ? "Guardada" : (modelData.security !== WifiSecurityType.Open ? "Protegida" : "Abierta")
                    trailing: Math.round(s * 100) + " %"
                    trailingIcon: modelData.known ? "more_horiz" : ""
                    reserveTrailing: true
                    active: modelData.connected
                    busy: modelData.stateChanging
                    onClicked: {
                        root.message = "";
                        if (modelData.connected)
                            modelData.disconnect();
                        else if (modelData.known || modelData.security === WifiSecurityType.Open)
                            modelData.connect();
                        else {
                            root.asking = modelData;
                            psk.focusInput();
                        }
                    }
                    onTrailingClicked: menu.target = (menu.target === modelData ? null : modelData)
                    Connections {
                        target: row.modelData
                        function onConnectionFailed(reason) {
                            const why = { NoSecrets: "falta la contraseña", WifiClientDisconnected: "se desconectó",
                                WifiClientFailed: "contraseña incorrecta o error del punto de acceso",
                                WifiAuthTimeout: "tiempo de autenticación agotado", WifiNetworkLost: "red perdida" };
                            const k = ConnectionFailReason.toString(reason);
                            root.message = "No se pudo conectar a «" + row.modelData.name + "»: " + (why[k] ?? k) + ".";
                            if (!row.modelData.known)
                                root.asking = row.modelData;
                        }
                    }
                }
            }
        }
    }

    // actions for a saved network
    RowLayout {
        id: menu
        property var target: null
        visible: target !== null
        Layout.fillWidth: true
        spacing: 6
        OText { Layout.fillWidth: true; text: menu.target?.name ?? ""; size: 12.5; color: Theme.colors.textMuted }
        OButton { text: "Compartir"; icon: "qr_code_2"; visible: (menu.target?.connected ?? false) && Settings.data.extras.wifiQr; onClicked: qr.show() }
        OButton { text: "Olvidar"; icon: "delete"; onClicked: { menu.target.forget(); menu.target = null; } }
    }

    // hidden network: name + password (optional), nmcli with a timeout — never waits on stdin
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        TextInput_ { id: hidden; Layout.fillWidth: true; placeholder: "Red oculta (nombre)" }
        TextInput_ { id: hiddenPsk; Layout.preferredWidth: 120; placeholder: "Contraseña"; password: true; visible: hidden.text !== "" }
        OButton {
            implicitHeight: 38
            text: "Conectar"
            enabled: hidden.text !== "" && !hiddenProc.running
            onClicked: {
                const cmd = ["nmcli", "--wait", "20", "device", "wifi", "connect", hidden.text, "hidden", "yes"];
                if (hiddenPsk.text !== "")
                    cmd.push("password", hiddenPsk.text);
                hiddenProc.command = cmd;
                hiddenProc.running = true;
                hiddenPsk.text = "";
            }
        }
    }
    Process {
        id: hiddenProc
        onExited: code => root.message = code === 0 ? "" : "No se pudo conectar a la red oculta (nombre o contraseña)."
    }

    // QR of the current network (password from NetworkManager; may need polkit → phase 6)
    Item {
        id: qr
        visible: path !== ""
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? 220 : 0
        property string path: ""
        function show(): void {
            const n = menu.target;
            // WIFI: QR with \ ; , : " escaped in SSID and password; SAE (WPA3) declared as such
            qrProc.command = ["sh", "-c",
                'command -v qrencode >/dev/null || exit 5; '
                + 'p=$(nmcli -s -g 802-11-wireless-security.psk connection show id "$1" 2>/dev/null) || exit 3; '
                + '[ -n "$p" ] || exit 3; '
                + 'k=$(nmcli -g 802-11-wireless-security.key-mgmt connection show id "$1" 2>/dev/null); '
                + 't=WPA; [ "$k" = sae ] && t=SAE; '
                + 'esc() { printf %s "$1" | sed \'s/[\\\\;,:"]/\\\\&/g\'; }; '
                + 'f="${XDG_RUNTIME_DIR:-/tmp}/ocarina-wifi-qr.png"; '
                + 'qrencode -s 8 -m 2 -o "$f" "WIFI:T:$t;S:$(esc "$1");P:$(esc "$p");;" && echo "$f"', "sh", n.name];
            qrProc.running = true;
        }
        // the image contains the password: delete it as soon as the page closes
        Component.onDestruction: if (path !== "") Quickshell.execDetached(["rm", "-f", path])
        Process {
            id: qrProc
            stdout: StdioCollector {
                onStreamFinished: qr.path = text.trim()
            }
            onExited: code => {
                if (code === 5)
                    root.message = "Falta qrencode (pacman -S qrencode).";
                else if (code === 3)
                    root.message = "Para leer la contraseña hace falta autorización: disponible tras la fase 6 (agente polkit propio).";
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 212
            height: 212
            radius: 14
            color: "#ffffff"
            Image {
                anchors.centerIn: parent
                width: 196
                height: 196
                source: qr.path ? "file://" + qr.path : ""
                cache: false
                smooth: false
            }
        }
    }
}
