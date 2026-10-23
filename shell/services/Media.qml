pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Active MPRIS player (docs/01-ARQUITECTURA §5). The Mpris types live in backends/MediaBackend.qml (capa 3.1);
// `player` is the MprisPlayer object itself, used by duck typing (Engawa, Hiroba, Nameraka).
Singleton {
    id: root

    property QtObject backend: null
    property string error: ""
    readonly property bool available: backend !== null
    readonly property QtObject player: backend?.player ?? null
    readonly property bool active: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""

    signal trackChanged

    function playPause(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }
    function next(): void {
        if (player?.canGoNext)
            player.next();
    }
    function previous(): void {
        if (player?.canGoPrevious)
            player.previous();
    }
    function stop(): void {
        player?.stop();
    }
    function changeVolume(delta: real): void {
        if (Math.abs(delta) > 1)
            delta = delta / 100;      // "5" from the CLI means 5 %
        if (!player?.volumeSupported)
            return;
        player.volume = Math.max(0, Math.min(1, player.volume + delta));
        Osd.show("volume", player.volume, player.identity, "music_note");
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { root.trackChanged(); }
    }

    Component.onCompleted: {
        const c = Qt.createComponent("backends/MediaBackend.qml");
        if (c.status === Component.Ready) {
            backend = c.createObject(root);
        } else {
            error = c.errorString();
            Health.fail("Multimedia (Quickshell.Services.Mpris)", error);
        }
    }
}
