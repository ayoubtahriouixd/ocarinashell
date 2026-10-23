pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// 音 Audio page: output and input devices (pick the default) and volume per application (PipeWire streams).
ColumnLayout {
    id: root
    spacing: 8
    signal back
    property bool embedded: false        // shown inside Settei (Red y Bluetooth / Sonido): no back button

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
    readonly property var sources: nodes.filter(n => !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
    readonly property var apps: nodes.filter(n => n.isStream && (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream)

    PwObjectTracker {
        objects: root.apps.concat([Pipewire.defaultAudioSource])
    }

    function name(n: var): string {
        return n.nickname || n.description || n.name;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Sonido"
        kanji: "音"
        onBack: root.back()
        showBack: !root.embedded
    }

    OText { text: "Salida"; size: 12; color: Theme.colors.textMuted; font.weight: Font.DemiBold }
    Repeater {
        model: root.sinks
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: /hdmi|displayport/i.test(modelData.description) ? "tv" : /head/i.test(modelData.description) ? "headphones" : "speaker"
            title: root.name(modelData)
            active: modelData === Pipewire.defaultAudioSink
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    OText { text: "Entrada"; size: 12; color: Theme.colors.textMuted; font.weight: Font.DemiBold; Layout.topMargin: 4 }
    Repeater {
        model: root.sources
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: "mic"
            title: root.name(modelData)
            active: modelData === Pipewire.defaultAudioSource
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
    OSlider {
        Layout.fillWidth: true
        visible: Pipewire.defaultAudioSource !== null
        label: Audio.micMuted ? "Micrófono, silenciado" : "Micrófono"
        icon: Audio.micMuted ? "mic_off" : "mic"
        value: Pipewire.defaultAudioSource?.audio?.volume ?? 0
        onMoved: v => { if (Pipewire.defaultAudioSource?.audio) Pipewire.defaultAudioSource.audio.volume = v; }
    }

    OText { visible: root.apps.length > 0; text: "Aplicaciones"; size: 12; color: Theme.colors.textMuted; font.weight: Font.DemiBold; Layout.topMargin: 4 }
    Repeater {
        model: root.apps
        delegate: ColumnLayout {
            id: app
            required property var modelData
            Layout.fillWidth: true
            spacing: 4
            OText {
                text: app.modelData.properties["application.name"] ?? root.name(app.modelData)
                size: 12
                color: Theme.colors.textMuted
            }
            OSlider {
                Layout.fillWidth: true
                label: "Volumen de " + (app.modelData.properties["application.name"] ?? root.name(app.modelData))
                icon: app.modelData.audio?.muted ? "volume_off" : "music_note"
                value: app.modelData.audio?.volume ?? 0
                onMoved: v => { if (app.modelData.audio) app.modelData.audio.volume = v; }
            }
        }
    }
}
