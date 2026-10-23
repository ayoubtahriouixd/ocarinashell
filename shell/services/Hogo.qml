pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// 保護 Hogo · OLED care (docs/07-IDEAS). Obi and Shima move their CONTENT (never the surface: the exclusive zone
// stays) through 4 positions of ±2 physical px every 15 min, and fade to 80 % after 3 min without pointer or
// changes. Everything hangs from Time's minute tick: no timer of its own. Off in Shinobi (already dimmed).
Singleton {
    id: root

    readonly property bool shiftOn: Settings.data.oled.pixelShift && !Modes.shinobi
    readonly property bool dimOn: Settings.data.oled.dimStatic && !Modes.shinobi
    property int cycleMinutes: Math.max(1, parseInt(Quickshell.env("OCARINA_HOGO_MINUTES") ?? "15") || 15)   // env: tests only
    property real scale: 1.75          // physical px per logical px of the panel (set by the bar from its window)
    property int phase: 0
    property double lastActivity: Date.now()
    property bool dimmed: false
    onDimOnChanged: if (!dimOn) dimmed = false     // entering Shinobi with the bar already dimmed: undo it at once

    // phases 0..3 → (0,+2) (+2,0) (0,−2) (−2,0) physical px, converted to logical
    readonly property real dx: shiftOn ? [0, 2, 0, -2][phase] / scale : 0
    readonly property real dy: shiftOn ? [0, 2, 0, -2][(phase + 1) % 4] / scale : 0

    function activity(): void {
        lastActivity = Date.now();
        dimmed = false;
    }

    Connections {
        target: Time
        function onMinuteTick() {
            const m = Time.now.getHours() * 60 + Time.now.getMinutes();
            if (root.shiftOn && m % root.cycleMinutes === 0)
                root.phase = (root.phase + 1) % 4;
            if (root.dimOn && !root.dimmed && Date.now() - root.lastActivity >= 3 * 60 * 1000)
                root.dimmed = true;
        }
    }
    Connections {
        target: Osd
        function onSerialChanged() { root.activity(); }
    }
}
