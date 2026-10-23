pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 音 Sonido: devices and per-app volume (Engawa's page, embedded) + interface sounds.
SetteiPage {
    id: page
    subtitle: "Dispositivos de salida y entrada, volumen por aplicación y sonidos de la interfaz."
    resetPaths: ["audio"]

    SectionTitle { text: "Volumen" }
    Card {
        SRow {
            title: "Volumen general"
            sub: Audio.sinkName
            leadIcon: Audio.icon
            titleWidth: 260
            HSlider {
                Layout.fillWidth: true
                value: Audio.volume
                stepSize: 0.01
                label: "Volumen general"
                onMoved: v => Audio.setVolume(v)
            }
            OText { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: Math.round(Audio.volume * 100) + " %"; size: 13; font.weight: Font.DemiBold; tabular: true }
        }
    }

    SectionTitle { text: "Dispositivos y aplicaciones" }
    EmbedCard {
        name: "Sonido"
        source: Qt.resolvedUrl("../../engawa/AudioPage.qml")
    }

    SectionTitle { text: "Sonidos de la interfaz" }
    Card {
        ToggleRow { title: "Sonidos de OcarinaShell"; sub: "Avisos, bloqueo y desbloqueo · nunca en Shinobi, No molestar ni bloqueado"; key: "audio.uiSounds" }
        SliderRow {
            title: "Volumen de los sonidos"
            key: "audio.uiVolume"
            dimmed: !Settings.data.audio.uiSounds
            from: 0
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + " %"
            onChanged: Sounds.play("notify")
        }
        SRow {
            title: "Probar"
            sub: "notify · critical · lock · unlock"
            dimmed: !Settings.data.audio.uiSounds
            Repeater {
                model: ["notify", "critical", "lock", "unlock"]
                delegate: OButton {
                    required property string modelData
                    text: modelData
                    icon: "play_arrow"
                    onClicked: Sounds.play(modelData)
                }
            }
        }
    }
}
