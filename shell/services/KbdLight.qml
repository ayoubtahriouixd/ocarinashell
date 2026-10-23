pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard backlight through UPower's KbdBacklight (system bus, no root; ThinkPad: 0 · 1 · 2).
// The level is read once at start and again whenever Engawa opens; while Engawa is open a `gdbus monitor` follows
// Fn+Space changes. Closed: zero processes. `available` stays false on machines without a keyboard backlight.
// What we ask for (`target`) is kept apart from what UPower reports: our own SetBrightness echoes back through the
// monitor, and while a request is in flight those echoes are ignored (else a drag 0 → 2 would stop at 1).
Singleton {
    id: root

    property int level: 0
    property int max: 0
    property int target: -1               // ≥ 0 while a request is pending
    readonly property bool available: max > 0
    readonly property bool watching: Panels.open === "engawa" && available

    readonly property var dest: ["org.freedesktop.UPower", "/org/freedesktop/UPower/KbdBacklight",
                                 "org.freedesktop.UPower.KbdBacklight"]

    function set(l: int): void {
        if (!available)
            return;
        l = Math.max(0, Math.min(max, l));
        if (l === level && target < 0)
            return;
        level = l;
        target = l;
        if (!setter.running)
            send();
    }
    // Fn+Space may have changed the level behind our back (nothing is watched with Engawa closed): read, then step
    property bool cycleAfterRead: false
    function cycle(): void {
        if (!available)
            return;
        cycleAfterRead = true;
        getLevel.running = true;
    }
    function send(): void {
        setter.sent = target;
        setter.command = ["busctl", "call"].concat(dest, ["SetBrightness", "i", String(target)]);
        setter.running = true;
    }
    function parseInt1(text: string): int {
        // busctl --json=short → {"type":"i","data":[2]}
        try {
            return JSON.parse(text).data[0] ?? -1;
        } catch (e) {
            return -1;
        }
    }

    onWatchingChanged: if (watching) getLevel.running = true

    Process {
        id: getMax
        running: true
        command: ["busctl", "--json=short", "call"].concat(root.dest, ["GetMaxBrightness"])
        stdout: StdioCollector {
            onStreamFinished: {
                root.max = Math.max(0, root.parseInt1(text));
                if (root.max > 0)
                    getLevel.running = true;
            }
        }
    }
    Process {
        id: getLevel
        command: ["busctl", "--json=short", "call"].concat(root.dest, ["GetBrightness"])
        stdout: StdioCollector {
            onStreamFinished: {
                const l = root.parseInt1(text);
                if (l >= 0 && root.target < 0)
                    root.level = l;
                if (root.cycleAfterRead) {
                    root.cycleAfterRead = false;
                    root.set((root.level + 1) % (root.max + 1));
                }
            }
        }
    }
    Process {
        id: setter
        property int sent: -1
        onExited: {
            if (root.target >= 0 && sent !== root.target)
                root.send();               // the slider moved on while this one ran
            else
                root.target = -1;
        }
    }
    Process {
        id: monitor
        running: root.watching
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.UPower",
                  "--object-path", "/org/freedesktop/UPower/KbdBacklight"]
        stdout: SplitParser {
            // …KbdBacklight.BrightnessChanged (2,)  /  …BrightnessChangedWithSource (2, 'internal')
            onRead: line => {
                if (root.target >= 0)
                    return;                // our own request echoing back
                const m = /BrightnessChanged\w* \((\d+)/.exec(line);
                if (m)
                    root.level = parseInt(m[1]);
            }
        }
        // UPower restarted while Engawa is open: follow it again (the binding alone stays true and would not)
        onExited: if (root.watching) restartMonitor.start()
    }
    Timer {
        id: restartMonitor
        interval: 2000
        onTriggered: if (root.watching && !monitor.running) monitor.running = true
    }
}
