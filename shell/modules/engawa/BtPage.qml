pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// 青 Bluetooth page. Isolated file (Quickshell.Bluetooth). Discovery only while the page is open.
ColumnLayout {
    id: root
    spacing: 8
    signal back
    property bool embedded: false        // shown inside Settei (Red y Bluetooth / Sonido): no back button

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices.values.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""))

    Component.onCompleted: if (adapter && adapter.enabled) adapter.discovering = true
    Connections {
        target: root.adapter
        function onEnabledChanged() { if (root.adapter.enabled) root.adapter.discovering = true; }
    }
    Component.onDestruction: if (adapter) adapter.discovering = false

    function icon(d: var): string {
        const i = d.icon || "";
        if (/headset|headphone|audio-headphones/.test(i)) return "headphones";
        if (/keyboard/.test(i)) return "keyboard";
        if (/mouse/.test(i)) return "mouse";
        if (/phone/.test(i)) return "smartphone";
        if (/audio|speaker/.test(i)) return "speaker";
        if (/gaming|joystick/.test(i)) return "sports_esports";
        return "bluetooth";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        kanji: "青"
        hasSwitch: true
        checked: root.adapter?.enabled ?? false
        onBack: root.back()
        showBack: !root.embedded
        onToggled: {
            if (!root.adapter)
                return;
            Bt.setEnabled(!root.adapter.enabled);   // saved across reboots (rfkill + Settings)
        }
    }
    OText {
        visible: !(root.adapter?.enabled ?? false)
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: root.adapter ? "Bluetooth apagado · actívalo con el interruptor para ver tus dispositivos" : "No hay adaptador Bluetooth"
        size: 12.5
        color: Theme.colors.textMuted
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }
    OText {
        visible: root.adapter?.discovering ?? false
        text: "Buscando dispositivos…"
        size: 12
        color: Theme.colors.textMuted
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2
            Repeater {
                model: root.devices
                delegate: ListRow {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: modelData.paired || modelData.name !== ""
                    icon: root.icon(modelData)
                    title: modelData.name || modelData.address
                    subtitle: modelData.connected ? "Conectado" : modelData.state === BluetoothDeviceState.Connecting ? "Conectando…"
                        : modelData.pairing ? "Emparejando…" : modelData.paired ? "Emparejado" : "Disponible"
                    // forget (unpair) needs a second click within 3 s
                    property bool confirm: false
                    trailing: confirm ? "¿Olvidar?" : (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + " %" : "")
                    trailingIcon: modelData.paired ? (confirm ? "delete_forever" : "delete") : ""
                    Timer { id: confirmTimer; interval: 3000; onTriggered: parent.confirm = false }
                    active: modelData.connected
                    busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                    onClicked: {
                        if (modelData.connected)
                            modelData.disconnect();
                        else if (modelData.paired)
                            modelData.connect();
                        else {
                            modelData.trusted = true;
                            modelData.pair();
                        }
                    }
                    onTrailingClicked: {
                        if (confirm) {
                            confirm = false;
                            modelData.forget();
                        } else {
                            confirm = true;
                            confirmTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
