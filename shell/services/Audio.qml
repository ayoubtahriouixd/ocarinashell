pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Volume and mute through Quickshell's PipeWire API (no wpctl in the hot path). Changes made here show the OSD;
// changes made elsewhere (pavucontrol, keyboard on another tool) only update the model.
// The PipeWire types live in backends/AudioBackend.qml (capa 3.1); if it fails, the CLI falls back to wpctl.
Singleton {
    id: root

    property QtObject backend: null
    property string error: ""
    readonly property QtObject sink: backend?.sink ?? null
    readonly property QtObject source: backend?.source ?? null
    readonly property bool available: (backend?.ready ?? false) && sink !== null
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    // friendly name: Altavoces / Auriculares / HDMI, else what PipeWire says
    readonly property string sinkName: {
        const d = (sink?.description ?? "") + " " + (sink?.name ?? "");
        if (/head(phone|set)/i.test(d))
            return "Auriculares";
        if (/hdmi|displayport/i.test(d))
            return "HDMI";
        if (/bluez|bluetooth/i.test(d))
            return sink?.description || "Bluetooth";
        if (/speaker|analog/i.test(d))
            return "Altavoces";
        return sink?.nickname || sink?.description || "Audio";
    }
    readonly property string icon: muted || volume <= 0.001 ? "volume_off"
        : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"

    function parseStep(step: string): real {
        const n = parseFloat(step);
        return isNaN(n) ? 0.05 : (n > 1 ? n / 100 : n);
    }
    function setVolume(v: real): void {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        Osd.show("volume", sink.audio.volume, sinkName, icon);
    }
    function increment(step: string): void {
        setVolume(volume + parseStep(step));
    }
    function decrement(step: string): void {
        setVolume(volume - parseStep(step));
    }
    function toggleMute(): void {
        if (!sink?.audio)
            return;
        sink.audio.muted = !sink.audio.muted;
        Osd.show("volume", sink.audio.muted ? 0 : sink.audio.volume, sink.audio.muted ? "Silenciado" : sinkName, icon);
    }
    function toggleMic(): void {
        if (!source?.audio)
            return;
        source.audio.muted = !source.audio.muted;
        Osd.show("mic", source.audio.muted ? 0 : 1, source.audio.muted ? "Micrófono silenciado" : "Micrófono activo",
                 source.audio.muted ? "mic_off" : "mic");
    }

    Component.onCompleted: {
        const c = Qt.createComponent("backends/AudioBackend.qml");
        if (c.status === Component.Ready) {
            backend = c.createObject(root);
        } else {
            error = c.errorString();
            Health.fail("Audio (Quickshell.Services.Pipewire)", error);
        }
    }
}
