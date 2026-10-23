pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 本番 Honban (docs/07-IDEAS): which SSH hosts are production. Source: bin/ocarina-honban (Host names of the ssh
// config marked «# ocarina: prod» + Settei → ssh.prodHosts; nothing else of the file is read). When the config
// file or the settings change it regenerates the niri rule (honban-rules.kdl: solid red ring + 2 px border, validated)
// and refreshes the list; Obi shows the 本番 seal next to the title of a production window («ssh · host»).
Singleton {
    id: root

    property var prod: []
    readonly property string sshConfig: {
        const p = Settings.data.ssh.configPath ?? "";
        return p === "" ? Paths.home + "/.ssh/config" : p.startsWith("~/") ? Paths.home + p.slice(1) : p;
    }
    // the ring uses the theme's `error` colour: a theme change regenerates the rule too
    readonly property string watchKey: Settings.ready
                                       ? JSON.stringify([Settings.data.ssh.enabled, sshConfig, Settings.data.ssh.prodHosts,
                                                         String(Theme.colors.error)])
                                       : ""

    function hostOf(title: string): string {
        const m = /^ssh · (\S+)$/.exec(title ?? "");
        return m ? m[1] : "";
    }
    function isProdTitle(title: string): bool {
        const h = hostOf(title);
        return h !== "" && prod.indexOf(h) >= 0;
    }

    onWatchKeyChanged: if (watchKey !== "") debounce.restart()
    Timer {
        id: debounce
        interval: 800
        onTriggered: {
            if (apply.running || list.running) {
                restart();
                return;
            }
            apply.running = true;
        }
    }
    // only the change notification: the file itself is never loaded here
    FileView {
        path: root.sshConfig
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }
    Process {
        id: apply
        command: [Paths.bin + "/ocarina-honban", "apply", "--quiet"]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("Honban:", text.trim())
        }
        onExited: list.running = true
    }
    Process {
        id: list
        command: [Paths.bin + "/ocarina-honban", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.prod = text.split("\n").filter(l => l.endsWith("\t1")).map(l => l.split("\t")[0])
        }
    }
}
