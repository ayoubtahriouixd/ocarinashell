pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 熱 Temperatures and power for 鬼 Oni (docs/02-DISENO §Shima: 「脳 78° 絵 71° 電 34 W」): Tctl from k10temp, the GPU
// edge temperature and the APU package power (PPT) from amdgpu's hwmon. Read every 2 s only while Oni is on (the
// island shows them and the thermal guard of Modes watches Tctl); nothing runs otherwise. The hwmon numbers change
// between boots, so the directories are looked up once, the first time they are needed.
Singleton {
    id: root

    readonly property bool wanted: Modes.oni
    property string k10: ""                 // /sys/class/hwmon/hwmonN of k10temp
    property string gpu: ""                 // … of amdgpu
    property bool discovered: false
    readonly property bool available: k10 !== "" || gpu !== ""
    property real cpuTemp: NaN              // °C
    property real gpuTemp: NaN              // °C
    property real watts: NaN                // W (PPT: CPU + GPU + SoC)
    property bool blind: false
    signal sampled                          // after every Tctl read (the guard counts samples, not changes)

    onWantedChanged: {
        if (wanted && !discovered && !finder.running)
            finder.running = true;
        if (!wanted) {
            cpuTemp = NaN;
            gpuTemp = NaN;
            watts = NaN;
        }
    }
    Process {
        id: finder
        command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do printf "%s %s\\n" "$(cat "$h/name" 2>/dev/null)" "$h"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const [name, dir] = l.split(" ");
                    if (name === "k10temp" && root.k10 === "")
                        root.k10 = dir;
                    else if (name === "amdgpu" && root.gpu === "")
                        root.gpu = dir;
                }
                root.discovered = true;
                if (!root.available)
                    console.warn("Sensors: sin k10temp ni amdgpu en hwmon");
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.wanted && root.discovered && root.available
        onTriggered: {
            if (root.k10 !== "")
                tctl.reload();
            if (root.gpu !== "") {
                edge.reload();
                ppt.reload();
            }
        }
    }
    FileView {
        id: tctl
        path: root.k10 !== "" ? root.k10 + "/temp1_input" : ""
        printErrors: false
        onLoaded: {
            root.cpuTemp = Number(text()) / 1000;
            root.sampled();
        }
        // the thermal guard depends on it: say so once instead of going blind quietly
        onLoadFailed: {
            if (root.wanted && !root.blind) {
                root.blind = true;
                Health.fail("Oni", "no se puede leer Tctl (" + path + "): sin guardia térmica");
            }
        }
    }
    FileView {
        id: edge
        path: root.gpu !== "" ? root.gpu + "/temp1_input" : ""
        printErrors: false
        onLoaded: root.gpuTemp = Number(text()) / 1000
    }
    FileView {
        id: ppt
        path: root.gpu !== "" ? root.gpu + "/power1_input" : ""
        printErrors: false
        onLoaded: root.watts = Number(text()) / 1e6
    }
}
