pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.mihari

// 見張 Mihari — system monitor (Ctrl+Alt+Supr / Mod+M). Cards: CPU (graph + one bar per core), memory, GPU, network,
// temperatures/fans/power; process table (filter, sort, terminate/kill with confirmation). All sampling is done by
// bin/ocarina-mihari, which runs only while this panel exists (it dies with it). Numbers follow btop's defaults.
PanelSurface {
    id: root
    implicitWidth: 1000
    implicitHeight: col.implicitHeight

    property var s: ({})                 // last sample
    property var procs: []
    property var hCpu: []
    property var hMem: []
    property var hGpu: []
    property var hRx: []
    property var hTx: []
    property string sortKey: "cpu"
    property bool sortDesc: true
    property string filter: ""
    property int selectedPid: -1
    property string confirm: ""          // "" | "TERM" | "KILL"
    property string message: ""

    function push(arr: var, v: real): var {
        const a = arr.length >= 60 ? arr.slice(arr.length - 59) : arr.slice();
        a.push(v);
        return a;
    }
    function gib(b: real): string {
        return (b / 1073741824).toFixed(1).replace(".", ",") + " GiB";
    }
    function size(b: real): string {
        if (b >= 1073741824)
            return gib(b);
        if (b >= 1048576)
            return Math.round(b / 1048576) + " MiB";
        return Math.round(b / 1024) + " KiB";
    }
    function rate(b: real): string {
        if (b >= 1048576)
            return (b / 1048576).toFixed(1).replace(".", ",") + " MB/s";
        if (b >= 1024)
            return Math.round(b / 1024) + " KB/s";
        return Math.round(b) + " B/s";
    }
    function pct(v: real): string {
        return (v ?? 0).toFixed(v >= 10 ? 0 : 1).replace(".", ",") + " %";
    }

    Process {
        id: sampler
        running: true
        command: ["python3", Paths.bin + "/ocarina-mihari"]
        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.s = d;
                root.hCpu = root.push(root.hCpu, d.cpu.total);
                root.hMem = root.push(root.hMem, d.mem.total > 0 ? 100 * d.mem.used / d.mem.total : 0);
                root.hGpu = root.push(root.hGpu, d.gpu?.busy ?? 0);
                root.hRx = root.push(root.hRx, d.net.rx);
                root.hTx = root.push(root.hTx, d.net.tx);
                if (d.procs)
                    root.procs = d.procs;
            }
        }
        onExited: code => {
            if (code !== 0 && code !== 15)
                Health.fail("Mihari", "el muestreador terminó con código " + code);
        }
    }

    // sorted + filtered process rows (at most 200 rows: the list is virtual anyway, this bounds the sort work)
    readonly property var rows: {
        const q = filter.trim().toLowerCase();
        let list = q === "" ? procs : procs.filter(p => p.name.toLowerCase().includes(q) || p.cmd.toLowerCase().includes(q)
                                                     || String(p.pid) === q || p.user.toLowerCase() === q);
        const k = sortKey, dir = sortDesc ? -1 : 1;
        list = list.slice().sort((a, b) => {
            const x = a[k], y = b[k];
            return (typeof x === "string" ? x.localeCompare(y) : x - y) * dir || a.pid - b.pid;
        });
        return list.slice(0, 200);
    }
    readonly property var selected: procs.find(p => p.pid === selectedPid) ?? null
    function move(d: int): void {
        const i = rows.findIndex(p => p.pid === selectedPid);
        const j = Math.max(0, Math.min(rows.length - 1, (i < 0 ? -1 : i) + d));
        if (rows[j])
            selectedPid = rows[j].pid;
        table.positionViewAtIndex(j, ListView.Contain);
    }
    function ask(sig: string): void {
        if (selected && !selected.protected)
            confirm = sig;
    }
    function send(): void {
        if (!selected || confirm === "")
            return;
        // through the sampler: it checks the pid still is the sampled process (start time) and refuses session ones
        killer.command = ["python3", Paths.bin + "/ocarina-mihari", "kill", confirm, String(selected.pid), String(selected.start)];
        killer.target = selected.name;
        killer.running = true;
        confirm = "";
    }
    Process {
        id: killer
        property string target: ""
        stderr: StdioCollector { id: killErr }
        onExited: code => {
            root.message = code === 0 ? "Señal enviada a " + target : target + ": " + killErr.text.trim();
            msgTimer.restart();
        }
    }
    Timer {
        id: msgTimer
        interval: 4000
        onTriggered: root.message = ""
    }

    Component.onCompleted: field.forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // ── header ───────────────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 10
            Kanji { text: "見張"; size: 22; color: Theme.colors.accent }
            OText { text: "Monitor del sistema"; size: 15; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            OText {
                text: root.s.load ? "carga " + root.s.load.map(v => v.toFixed(2).replace(".", ",")).join(" · ") : "midiendo…"
                size: 12
                tabular: true
                color: Theme.colors.textMuted
            }
        }

        // ── cards ────────────────────────────────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            columns: 3
            columnSpacing: 10
            rowSpacing: 10

            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                kanji: "脳"
                label: "CPU" + (root.s.cpu ? " · " + root.s.cpu.ghz.toFixed(1).replace(".", ",") + " GHz" : "")
                value: root.pct(root.s.cpu?.total ?? 0)
                history: root.hCpu
                tint: Theme.colors.accent
                // one bar per core
                Row {
                    width: parent.width
                    height: 30
                    spacing: 3
                    Repeater {
                        // a count, not the array: the 16 bars stay alive and only their value changes
                        model: (root.s.cpu?.cores ?? []).length
                        delegate: Rectangle {
                            id: core
                            required property int index
                            readonly property real modelData: root.s.cpu?.cores?.[index] ?? 0
                            width: (parent.width - 3 * ((root.s.cpu?.cores ?? []).length - 1)) / Math.max(1, (root.s.cpu?.cores ?? []).length)
                            height: 30
                            radius: 2
                            color: Theme.alpha(Theme.colors.text, 0.06)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(2, parent.height * Math.min(1, core.modelData / 100))
                                radius: 2
                                color: core.modelData > 85 ? Theme.colors.accent : Theme.alpha(Theme.colors.accent, 0.55)
                            }
                        }
                    }
                }
            }
            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                kanji: "記"
                label: "Memoria"
                value: root.s.mem ? root.gib(root.s.mem.used) : "—"
                detail: root.s.mem ? "de " + root.gib(root.s.mem.total) + " · caché " + root.gib(root.s.mem.cached)
                    + (root.s.mem.swapTotal > 0 ? " · zram " + root.size(root.s.mem.swapUsed) : "") : ""
                history: root.hMem
                tint: Theme.colors.info
            }
            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                kanji: "絵"
                label: "GPU · Radeon"
                value: root.s.gpu?.busy !== undefined ? root.pct(root.s.gpu.busy) : "—"
                detail: root.s.gpu?.vramUsed !== undefined ? "VRAM " + root.size(root.s.gpu.vramUsed) + " de " + root.gib(root.s.gpu.vramTotal)
                    + " · GTT " + root.size(root.s.gpu.gttUsed) : ""
                history: root.hGpu
                tint: Theme.colors.accent2
            }
            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                kanji: "網"
                label: "Red"
                value: root.s.net ? "↓ " + root.rate(root.s.net.rx) : "—"
                detail: root.s.net ? "↑ " + root.rate(root.s.net.tx) : ""
                history: root.hRx
                max: Math.max(1024, ...root.hRx, ...root.hTx)
                tint: Theme.colors.info
                Sparkline {
                    width: parent.width
                    height: 22
                    values: root.hTx
                    max: Math.max(1024, ...root.hRx, ...root.hTx)
                    color: Theme.colors.accent
                }
            }
            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                graph: false
                kanji: "熱"
                label: "Temperaturas"
                value: (root.s.temps ?? []).length > 0 ? Math.round(root.s.temps[0].c) + " °C" : "—"
                detail: (root.s.fans ?? []).some(f => f > 0) ? "Ventiladores " + root.s.fans.filter(f => f > 0).join(" · ") + " rpm" : "Ventiladores parados"
                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 3
                    Repeater {
                        model: (root.s.temps ?? []).length
                        delegate: RowLayout {
                            id: tr
                            required property int index
                            readonly property var modelData: root.s.temps?.[index] ?? { label: "", c: 0 }
                            Layout.fillWidth: true
                            spacing: 6
                            OText { Layout.fillWidth: true; text: tr.modelData.label; size: 12; color: Theme.colors.textMuted }
                            OText {
                                text: Math.round(tr.modelData.c) + " °C"
                                size: 12
                                tabular: true
                                color: tr.modelData.c >= 85 ? Theme.colors.accent : Theme.colors.text
                            }
                        }
                    }
                }
            }
            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                graph: false
                kanji: "電"
                label: "Energía"
                value: root.s.bat?.watts !== undefined ? root.s.bat.watts.toFixed(1).replace(".", ",") + " W" : "—"
                detail: root.s.bat ? (root.s.bat.status === "Discharging" ? "Batería · " : root.s.bat.status === "Charging" ? "Cargando · " : "Enchufado · ")
                    + Math.round(root.s.bat.pct) + " %" : ""
                OText {
                    width: parent.width
                    text: root.s.gpu?.watts !== undefined ? "Paquete del SoC " + root.s.gpu.watts.toFixed(1).replace(".", ",") + " W" : ""
                    size: 12
                    tabular: true
                    color: Theme.colors.textMuted
                }
            }
        }

        // ── processes ────────────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 10
            Kanji { text: "工程"; size: 14; color: Theme.colors.textMuted }
            OText { text: "Procesos · " + root.procs.length; size: 13; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            OText { visible: root.message !== ""; text: root.message; size: 12; color: Theme.colors.accent }
            TextInput_ {
                id: field
                Layout.preferredWidth: 240
                implicitHeight: 34
                placeholder: "Filtrar (nombre, PID, usuario)"
                onTextChanged: root.filter = text
                Keys.onPressed: event => {
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                    if (event.key === Qt.Key_Down) root.move(1);
                    else if (event.key === Qt.Key_Up) root.move(-1);
                    else if (event.key === Qt.Key_PageDown) root.move(10);
                    else if (event.key === Qt.Key_PageUp) root.move(-10);
                    else if (event.key === Qt.Key_Delete) root.ask(shift ? "KILL" : "TERM");
                    else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.confirm !== "") root.send();
                    else if (event.key === Qt.Key_Escape && root.confirm !== "") root.confirm = "";
                    else return;
                    event.accepted = true;
                }
            }
        }
        // column headers (click to sort)
        RowLayout {
            id: headers
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            spacing: 0
            component Head: OText {
                id: h
                required property string key
                required property string title
                size: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                color: root.sortKey === key ? Theme.colors.text : Theme.colors.textDim
                text: title.toUpperCase() + (root.sortKey === key ? (root.sortDesc ? " ↓" : " ↑") : "")
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.sortKey === h.key)
                            root.sortDesc = !root.sortDesc;
                        else {
                            root.sortKey = h.key;
                            root.sortDesc = h.key === "cpu" || h.key === "rss";
                        }
                    }
                }
            }
            Head { Layout.fillWidth: true; key: "name"; title: "Proceso" }
            Head { Layout.preferredWidth: 80; key: "pid"; title: "PID"; horizontalAlignment: Text.AlignRight }
            Head { Layout.preferredWidth: 120; Layout.leftMargin: 18; key: "user"; title: "Usuario" }
            Head { Layout.preferredWidth: 80; key: "cpu"; title: "CPU"; horizontalAlignment: Text.AlignRight }
            Head { Layout.preferredWidth: 100; key: "rss"; title: "Memoria"; horizontalAlignment: Text.AlignRight }
        }
        ListView {
            id: table
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 340
            clip: true
            // keyed by pid: a new sample updates rows in place (no rebuild, the scroll position stays)
            model: ScriptModel {
                values: root.rows
                objectProp: "pid"
            }
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: prow
                required property var modelData
                readonly property bool sel: modelData.pid === root.selectedPid
                width: table.width
                height: 34
                Rectangle {
                    anchors.fill: parent
                    color: prow.sel ? Theme.colors.surface2 : rowHov.hovered ? Theme.alpha(Theme.colors.surface2, 0.5) : "transparent"
                }
                Rectangle {
                    visible: prow.sel
                    y: 7
                    width: 3
                    height: parent.height - 14
                    radius: 1.5
                    color: Theme.colors.accent
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        OText { text: prow.modelData.name; size: 13; font.weight: Font.Medium }
                        OText {
                            Layout.fillWidth: true
                            text: prow.modelData.cmd
                            size: 11.5
                            color: Theme.colors.textDim
                            elide: Text.ElideRight
                        }
                    }
                    OText { Layout.preferredWidth: 80; text: prow.modelData.pid; size: 12.5; tabular: true; horizontalAlignment: Text.AlignRight; color: Theme.colors.textMuted }
                    OText { Layout.preferredWidth: 120; Layout.leftMargin: 18; text: prow.modelData.user; size: 12.5; elide: Text.ElideRight; color: Theme.colors.textMuted }
                    OText {
                        Layout.preferredWidth: 80
                        text: root.pct(prow.modelData.cpu)
                        size: 12.5
                        tabular: true
                        horizontalAlignment: Text.AlignRight
                        color: prow.modelData.cpu >= 50 ? Theme.colors.accent : Theme.colors.text
                    }
                    OText { Layout.preferredWidth: 100; text: root.size(prow.modelData.rss); size: 12.5; tabular: true; horizontalAlignment: Text.AlignRight }
                }
                HoverHandler { id: rowHov }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedPid = prow.modelData.pid;
                        field.forceActiveFocus();
                    }
                }
            }
        }

        // ── footer: actions / confirmation ───────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; Layout.preferredHeight: 1; color: Theme.colors.outline }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 10
            // keys
            Row {
                visible: root.confirm === ""
                spacing: 14
                KeyHint { keys: ["↑", "↓"]; text: "elegir" }
                KeyHint { keys: ["Supr"]; text: "terminar" }
                KeyHint { keys: ["Shift", "Supr"]; text: "forzar" }
            }
            OText {
                visible: root.confirm !== ""
                Layout.fillWidth: true
                text: root.selected ? (root.confirm === "KILL" ? "¿Forzar el cierre de «" : "¿Terminar «") + root.selected.name + "» (" + root.selected.pid + ")?"
                    + (root.confirm === "KILL" ? " Perderá lo no guardado." : "") : ""
                size: 13
                color: Theme.colors.text
            }
            Item { Layout.fillWidth: root.confirm === "" }
            OButton {
                visible: root.confirm !== ""
                text: "Cancelar"
                ghost: true
                onClicked: root.confirm = ""
            }
            OButton {
                visible: root.confirm !== ""
                text: root.confirm === "KILL" ? "Forzar" : "Terminar"
                primary: true
                onClicked: root.send()
            }
            OButton {
                visible: root.confirm === ""
                enabled: root.selected !== null && !root.selected.protected
                opacity: enabled ? 1 : 0.4
                text: "Terminar"
                icon: "close"
                onClicked: root.ask("TERM")
            }
            OButton {
                visible: root.confirm === ""
                enabled: root.selected !== null && !root.selected.protected
                opacity: enabled ? 1 : 0.4
                text: "Forzar"
                icon: "dangerous"
                onClicked: root.ask("KILL")
            }
            OText {
                visible: root.confirm === "" && (root.selected?.protected ?? false)
                text: "鍵 Protegido: es parte de la sesión"
                size: 12
                color: Theme.colors.textMuted
            }
            OText { visible: root.confirm === ""; text: "見張 · Super+M"; font.family: Theme.font.jp; size: 12; color: Theme.colors.textMuted }
        }
    }
}
