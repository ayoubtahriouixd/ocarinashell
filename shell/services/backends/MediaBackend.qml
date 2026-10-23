import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Sensitive module (Quickshell.Services.Mpris) isolated in its own file (docs/06 capa 3.1).
// Active player: the one playing, else the last one that played (docs/01-ARQUITECTURA §5).
QtObject {
    id: backend

    property MprisPlayer lastPlayed: null
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        for (const p of list)
            if (p.isPlaying)
                return p;
        if (lastPlayed && list.indexOf(lastPlayed) >= 0)
            return lastPlayed;
        return list.length > 0 ? list[0] : null;
    }
    readonly property bool playing: player?.isPlaying ?? false

    onPlayerChanged: if (player && player.isPlaying) lastPlayed = player
    onPlayingChanged: if (playing) lastPlayed = player
}
