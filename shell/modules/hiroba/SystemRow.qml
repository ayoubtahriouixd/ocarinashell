pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · the machine at a glance: CPU, GPU, memory, temperature, battery (with watts) and network, each with 30 s of
// history. Sampled by bin/ocarina-mihari --light (no process list) once a second, and ONLY while 広場 is open: the
// sampler lives and dies with this row.
RowLayout {
    id: root
    spacing: 14
    property var s: ({})
    property var hNet: []                 // 30 s of download rate: scales the network ring
    function push(a: var, v: real): var {
        const o = a.concat([v]);
        return o.length > 30 ? o.slice(o.length - 30) : o;
    }
    function rate(b: real): var {
        if (b >= 1048576) return [(b / 1048576).toFixed(1).replace(".", ","), "MB/s ↓"];
        if (b >= 1024) return [Math.round(b / 1024), "KB/s ↓"];
        return [Math.round(b), "B/s ↓"];
    }
    readonly property real cpuTemp: (s.temps ?? []).find(t => t.label === "CPU")?.c ?? 0
    Process {
        running: !Modes.shinobi
        command: ["python3", Paths.bin + "/ocarina-mihari", "1", "--light"]
        stdout: SplitParser {
            onRead: line => {
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }
                root.s = d;
                root.hNet = root.push(root.hNet, (d.net?.rx ?? 0) / 1024);
            }
        }
    }
    readonly property var net: rate(s.net?.rx ?? 0)

    readonly property real gib: 1073741824
    readonly property real netMax: Math.max(131072, ...root.hNet.map(v => v * 1024))
    RingGauge {
        Layout.fillWidth: true; glyph: "脳"; name: "CPU"; tint: Theme.colors.accent
        value: Math.round(root.s.cpu?.total ?? 0); unit: "%"; fraction: (root.s.cpu?.total ?? 0) / 100
        detail: (root.s.cpu?.ghz ?? 0).toFixed(1).replace(".", ",") + " GHz"
    }
    RingGauge {
        Layout.fillWidth: true; glyph: "絵"; name: "GPU"; tint: Theme.colors.sakura
        value: Math.round(root.s.gpu?.busy ?? 0); unit: "%"; fraction: (root.s.gpu?.busy ?? 0) / 100
        detail: ((root.s.gpu?.watts ?? 0) > 0 ? root.s.gpu.watts.toFixed(1).replace(".", ",") + " W" : ((root.s.gpu?.vramUsed ?? 0) / root.gib).toFixed(1).replace(".", ",") + " GB")
    }
    RingGauge {
        Layout.fillWidth: true; glyph: "記"; name: "RAM"; tint: Theme.colors.info
        value: Math.round(100 * (root.s.mem?.used ?? 0) / Math.max(1, root.s.mem?.total ?? 1)); unit: "%"
        fraction: (root.s.mem?.used ?? 0) / Math.max(1, root.s.mem?.total ?? 1)
        detail: ((root.s.mem?.used ?? 0) / root.gib).toFixed(1).replace(".", ",") + "/" + Math.round((root.s.mem?.total ?? 0) / root.gib) + " GB"
    }
    RingGauge {
        Layout.fillWidth: true; glyph: "熱"; name: "Temp."; tint: root.cpuTemp >= 85 ? Theme.colors.error : Theme.colors.warning
        value: Math.round(root.cpuTemp); unit: "°C"; fraction: root.cpuTemp / 100
        detail: (root.s.fans ?? []).length ? root.s.fans[0] + " rpm" : "GPU " + Math.round((root.s.temps ?? []).find(t => t.label === "GPU")?.c ?? 0) + "°"
    }
    RingGauge {
        Layout.fillWidth: true; glyph: "電"; name: "Batería"; tint: Power.low ? Theme.colors.error : Theme.colors.success
        value: Math.round(Power.percent * 100); unit: "%"; fraction: Power.percent
        detail: (root.s.bat?.watts ?? 0) > 0.05 ? root.s.bat.watts.toFixed(1).replace(".", ",") + " W" + (Power.charging ? " · cargando" : "")
            : Power.charging ? "cargando" : Power.onBattery ? "batería" : "enchufado"
    }
    RingGauge {
        Layout.fillWidth: true; glyph: "網"; name: "Red"; tint: Theme.colors.info      // asagi is Fune's
        value: root.net[0]; unit: root.net[1].replace(" ↓", ""); fraction: (root.s.net?.rx ?? 0) / root.netMax
        detail: "↑" + root.rate(root.s.net?.tx ?? 0)[0] + " " + root.rate(root.s.net?.tx ?? 0)[1].replace(" ↓", "")
    }
}
