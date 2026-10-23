pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// UI sounds with pw-play (no QtMultimedia). Silent in Shinobi, Do-not-disturb and while locked (except unlock).
Singleton {
    id: root

    readonly property bool enabled: Settings.data.audio.uiSounds
    property bool dnd: Settings.data.notifications.dnd
    property bool locked: false

    function play(name: string): void {
        if (!enabled || dnd || Notifs.oniDnd || Modes.quiet || (locked && name !== "unlock"))
            return;
        Quickshell.execDetached(["pw-play", "--volume", String(Settings.data.audio.uiVolume),
                                 Paths.asset("sounds/" + name + ".wav")]);
    }
}
