pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Which external tools exist (docs/06-ACTUALIZACIONES: detect capabilities, never assume them). Probed once at
// start with a single `command -v`; the UI says «falta X» instead of showing an empty list.
Singleton {
    id: root
    readonly property var names: ["cliphist", "wl-copy", "wtype", "rg", "qalc", "fd", "jq", "vips", "niri", "curl", "ghostty",
                                  "wl-mirror", "matugen", "busctl", "udevadm", "wlsunset", "checkupdates"]
    property var found: ({})
    property bool probed: false
    function has(name: string): bool {
        return !probed || found[name] === true;      // optimistic until probed
    }
    Process {
        running: true
        command: ["sh", "-c", 'for t in "$@"; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done', "sh"].concat(root.names)
        stdout: StdioCollector {
            onStreamFinished: {
                const f = {};
                for (const l of text.split("\n"))
                    if (l !== "")
                        f[l] = true;
                root.found = f;
                root.probed = true;
            }
        }
    }
}
