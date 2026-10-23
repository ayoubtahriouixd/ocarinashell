pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Terminal and editor effects (Ghostty 墨 ink cursor, config/ghostty/shaders/ink-cursor.glsl; Neovim smear cursor,
// smooth scroll and snacks animations) and Ghostty's background opacity. Cursor trails: only with AC power, outside 忍 Shinobi and with motion enabled
// (their animation loops cost battery). Short UI motion in Neovim: outside Shinobi and with motion enabled.
// The decision is written by `ocarina-theme effects on|off --motion on|off` (only owner of the Ghostty include and
// of theme/effects.json, which Neovim watches; Ghostty reloads only when its include changes). Debounced:
// plugging/unplugging the charger never spawns a burst.
Singleton {
    id: root

    readonly property bool want: Settings.ready && Settings.data.terminal.inkCursor && !Power.onBattery
                                 && !Modes.shinobi && Motion.enabled
    readonly property bool wantMotion: !Modes.shinobi && Motion.enabled
    // Theme.transparency is already false in Shinobi and Oni (Theme.lean)
    readonly property real wantOpacity: Settings.ready && Theme.transparency
                                        ? Math.round(Math.max(0.5, Math.min(1, Settings.data.terminal.opacity ?? 1)) * 100) / 100 : 1
    property bool applied: false
    property bool appliedMotion: false
    property real appliedOpacity: -1
    property bool known: false
    property bool failed: false

    // the fish greeting reads its switches from the daily cache: rewrite it when they change (after settings.json)
    readonly property string greetKey: Settings.ready
                                       ? [Settings.data.terminal.greeting, Settings.data.terminal.fastfetchDaily].join()
                                       : ""
    property string lastGreetKey: ""
    onGreetKeyChanged: {
        if (greetKey === "")
            return;
        if (lastGreetKey === "")
            lastGreetKey = greetKey;      // start-up / hot reload: the cache already matches
        else if (greetKey !== lastGreetKey)
            dailyDelay.restart();
    }
    Timer {
        id: dailyDelay
        interval: 2000
        onTriggered: {
            if (daily.running) {
                restart();
                return;
            }
            root.lastGreetKey = root.greetKey;
            daily.running = true;
        }
    }
    Process {
        id: daily
        command: [Paths.bin + "/ocarina-daily", "--force", "--quiet"]
    }

    onWantChanged: debounce.restart()
    onWantMotionChanged: debounce.restart()
    onWantOpacityChanged: debounce.restart()
    Component.onCompleted: debounce.restart()

    Timer {
        id: debounce
        interval: 1200
        onTriggered: {
            if (root.known && root.applied === root.want && root.appliedMotion === root.wantMotion
                    && root.appliedOpacity === root.wantOpacity)
                return;
            if (writer.running) {
                restart();
                return;
            }
            writer.target = root.want;
            writer.targetMotion = root.wantMotion;
            writer.targetOpacity = root.wantOpacity;
            writer.command = [Paths.bin + "/ocarina-theme", "effects", root.want ? "on" : "off",
                              "--motion", root.wantMotion ? "on" : "off", "--opacity", String(root.wantOpacity), "--quiet"];
            writer.running = true;
        }
    }
    Process {
        id: writer
        property bool target: false
        property bool targetMotion: false
        property real targetOpacity: 1
        onExited: code => {
            if (code === 0) {
                if (root.known === false || root.failed)
                    Health.ok("Efectos de terminal");
                root.failed = false;
                root.applied = target;
                root.appliedMotion = targetMotion;
                root.appliedOpacity = targetOpacity;
                root.known = true;
            } else {
                console.warn("TermFx: ocarina-theme effects falló (" + code + ")");
                root.failed = true;
                Health.fail("Efectos de terminal", "ocarina-theme effects terminó con " + code);
            }
        }
    }
}
