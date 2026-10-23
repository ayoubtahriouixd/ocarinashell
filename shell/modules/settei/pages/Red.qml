pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 網 Red y Bluetooth: Engawa's Wi-Fi and Bluetooth pages side by side (scanning only while this page is open).
SetteiPage {
    id: page
    subtitle: "Redes Wi-Fi y dispositivos Bluetooth. Solo se busca mientras esta página está abierta."
    resetPaths: []

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 18
        spacing: 14
        EmbedCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            name: "Wi-Fi"
            source: Qt.resolvedUrl("../../engawa/WifiPage.qml")
        }
        EmbedCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            name: "Bluetooth"
            source: Qt.resolvedUrl("../../engawa/BtPage.qml")
        }
    }

    SectionTitle { text: "Extras" }
    Card {
        ToggleRow { title: "Compartir el Wi-Fi con un QR"; sub: "Botón en la página de Wi-Fi de Engawa"; key: "extras.wifiQr" }
        ToggleRow { title: "Mosaico VPN"; sub: "En Engawa, si NetworkManager tiene alguna VPN o WireGuard"; key: "extras.vpnTile" }
    }

    SectionTitle { text: "本番 SSH de producción" }
    Card {
        ToggleRow { title: "Hosts SSH en Torii y Honban"; sub: "Solo se leen los nombres «Host» de ~/.ssh/config: nunca claves ni known_hosts"; key: "ssh.enabled" }
        SRow {
            title: "Hosts de producción"
            sub: "Separados por comas. También vale «# ocarina: prod» dentro de su bloque Host · anillo rojo y sello 本番"
            dimmed: !Settings.data.ssh.enabled
            TextInput_ {
                id: prodField
                Layout.preferredWidth: 300
                placeholder: "db-prod, web-prod…"
                readonly property string saved: (Settings.data.ssh.prodHosts ?? []).join(", ")
                // never overwrite what is being typed (a settings reload replaces the whole data object)
                Binding on text {
                    when: !prodField.editing
                    value: prodField.saved
                }
                function commit(): void {
                    const list = text.split(/[\s,]+/).filter(h => /^[A-Za-z0-9._@-]+$/.test(h));
                    if (JSON.stringify(list) !== JSON.stringify(Settings.data.ssh.prodHosts ?? []))
                        Settings.set("ssh.prodHosts", list);
                    text = list.join(", ");         // show exactly what was kept
                }
                onEditingFinished: commit()
            }
        }
        SRow {
            visible: Settings.data.ssh.enabled
            title: "En producción ahora"
            OText {
                text: Honban.prod.length > 0 ? Honban.prod.join(" · ") : "ninguno"
                size: 13
                color: Honban.prod.length > 0 ? Theme.colors.error : Theme.colors.textDim
            }
        }
    }
}
