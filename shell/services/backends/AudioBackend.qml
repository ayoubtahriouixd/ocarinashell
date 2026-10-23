import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Sensitive module (Quickshell.Services.Pipewire) isolated in its own file (docs/06 capa 3.1). Audio uses the
// default nodes by duck typing (`sink.audio.volume`…), so the singleton never names a PipeWire type.
QtObject {
    id: backend

    readonly property bool ready: Pipewire.ready
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
}
