pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// 窓 Mado — window rules without editing KDL (Mod+Shift+Y). Shows the focused window (app-id, title), a form
// (floating, maximized, width, opacity, corners, workspace, focus, hide from captures) with a live KDL preview, and
// the rules already made. Rules live in state/niri/user-rules.kdl (one block per rule, marked «// mado:»), are
// validated with `niri validate` by bin/ocarina-mado before replacing the file, and niri reloads them by itself.
PanelSurface {
    id: root
    implicitWidth: 680
    implicitHeight: col.implicitHeight + 8

    // target: the focused window when Mado opened (a layer surface does not take niri's window focus)
    property string appId: Niri.focusedWindow?.app_id ?? ""
    property string winTitle: Niri.focusedWindow?.title ?? ""
    Component.onCompleted: {
        appId = appId;                       // freeze: later focus changes must not retarget the form
        winTitle = winTitle;
        rulesFile.reload();
    }
    readonly property var otherApps: {
        const seen = {}, out = [];
        for (const id in Niri.windows) {
            const a = Niri.windows[id].app_id ?? "";
            if (a !== "" && !seen[a]) {
                seen[a] = true;
                out.push({ appId: a, title: Niri.windows[id].title ?? "" });
            }
        }
        return out.sort((x, y) => x.appId.localeCompare(y.appId));
    }
    readonly property var namedWorkspaces: Niri.workspaces.filter(w => !!w.name).map(w => w.name)

    // form
    property bool matchTitle: false
    property bool floating: false
    property bool maximized: false
    property bool noFocus: false
    property bool hideCaptures: false
    property string width_: ""             // "" | proportion
    property string corners: ""            // "" | radius px
    property string workspace: ""
    property real opacity_: 1

    // window data is untrusted (any app sets its own app-id and title): control characters are dropped — a newline
    // would end the «// mado:» comment and let the rest become top-level KDL — and strings are written as ordinary
    // KDL strings with full escaping, never as raw strings (a «"#» inside would close them)
    function clean(s: string): string {
        return (s ?? "").replace(/[\x00-\x1f\x7f\u2028\u2029]/g, " ");
    }
    function kstr(s: string): string {
        return '"' + clean(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }
    function rx(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }
    readonly property string kdl: {
        if (appId === "")
            return "";
        const l = [];
        l.push("window-rule {");
        l.push("    match app-id=" + kstr("^" + rx(appId) + "$") + (matchTitle && winTitle !== "" ? " title=" + kstr(rx(winTitle)) : ""));
        if (floating) l.push("    open-floating true");
        if (maximized) l.push("    open-maximized true");
        if (noFocus) l.push("    open-focused false");
        if (width_ !== "") l.push("    default-column-width { proportion " + width_ + "; }");
        if (workspace !== "") l.push("    open-on-workspace " + kstr(workspace));
        if (opacity_ < 0.995) l.push("    opacity " + opacity_.toFixed(2));
        if (corners !== "") {
            l.push("    geometry-corner-radius " + corners);
            l.push("    clip-to-geometry true");
        }
        if (hideCaptures) l.push('    block-out-from "screen-capture"');
        l.push("}");
        return l.length > 3 ? l.join("\n") : "";
    }

    // ── existing rules ───────────────────────────────────────────────────────────────────────
    readonly property string header: "// 窓 Mado · reglas de ventana creadas desde OcarinaShell (ocarina-mado las valida antes de guardar).\n"
        + "// Se puede editar a mano: cada regla empieza con «// mado:».\n\n"
    property var rules: []                 // [{ label, body }]
    function parse(text: string): void {
        const out = [];
        const parts = text.split(/^\/\/ mado: /m);
        preamble = parts[0];
        for (let i = 1; i < parts.length; i++) {
            const nl = parts[i].indexOf("\n");
            const label = parts[i].slice(0, nl).trim();
            const body = parts[i].slice(nl + 1).trim();
            const opts = body.split("\n").map(s => s.trim()).filter(s => s && !s.startsWith("match") && s !== "}" && !s.startsWith("window-rule"));
            out.push({ label: label, body: body, summary: opts.map(root.human).filter(x => x).join(" · ") });
        }
        rules = out;
    }
    // one KDL line of a rule in words ("opacity 0.90" → "opacidad 90 %"); unknown lines are shown as they are
    function human(line: string): string {
        const frac = { "0.33333": "1/3", "0.5": "1/2", "0.66667": "2/3", "1.0": "completo" };
        let m;
        if (line === "open-floating true") return "flotante";
        if (line === "open-maximized true") return "maximizada";
        if (line === "open-focused false") return "sin foco al abrir";
        if (line === "clip-to-geometry true") return "";
        if ((m = /^default-column-width \{ proportion ([\d.]+); \}$/.exec(line))) return "ancho " + (frac[m[1]] ?? m[1]);
        if ((m = /^opacity ([\d.]+)$/.exec(line))) return "opacidad " + Math.round(parseFloat(m[1]) * 100) + " %";
        if ((m = /^geometry-corner-radius (\d+)$/.exec(line))) return m[1] === "0" ? "esquinas rectas" : "esquinas " + m[1] + " px";
        if ((m = /^open-on-workspace "(.*)"$/.exec(line))) return "espacio «" + m[1] + "»";
        if (/^block-out-from/.test(line)) return "oculta en capturas";
        return line;
    }
    FileView {
        id: rulesFile
        path: Paths.state + "/niri/user-rules.kdl"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.rules = []
    }
    // whatever precedes the first «// mado:» (header, hand-written rules) is kept as it is
    property string preamble: ""
    function compose(list: var): string {
        return (preamble.trim() !== "" ? preamble.replace(/\s*$/, "\n\n") : header)
            + list.map(r => "// mado: " + clean(r.label) + "\n" + r.body + "\n").join("\n");
    }

    property string status: ""
    property bool failed: false
    function save(list: var, okText: string): void {
        applier.okText = okText;
        applier.command = ["sh", "-c", 'printf "%s" "$1" | "$0" apply', Paths.bin + "/ocarina-mado", compose(list)];
        applier.running = true;
    }
    function addRule(): void {
        if (kdl === "")
            return;
        const label = clean(appId) + (matchTitle ? " · «" + clean(winTitle).slice(0, 40) + "»" : "");
        save(rules.concat([{ label: label, body: kdl }]), "Regla guardada: se aplica a las ventanas nuevas de " + appId);
    }
    function removeRule(i: int): void {
        save(rules.filter((_, k) => k !== i), "Regla borrada");
    }
    Process {
        id: applier
        property string okText: ""
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            root.failed = code !== 0;
            root.status = code === 0 ? okText : "niri no la acepta: " + applyErr.text.trim().split("\n").slice(-4).join(" ");
        }
    }

    component Toggle: RowLayout {
        id: tg
        property string text
        property bool checked
        signal toggled
        spacing: 10
        OText { Layout.fillWidth: true; text: tg.text; size: 13 }
        Switch_ { label: tg.text; checked: tg.checked; onToggled: tg.toggled() }
    }
    // section label, the same small caps as «REGLAS CREADAS» (mock.css .sect)
    component Field: OText {
        size: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        color: Theme.colors.textDim
        font.capitalization: Font.AllUppercase
    }

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
            Kanji { text: "窓"; size: 22; color: Theme.colors.accent }
            OText { text: "Reglas de ventana"; size: 15; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            OText { text: "窓 · Super+Shift+Y"; font.family: Theme.font.jp; size: 12; color: Theme.colors.textMuted }
        }

        // ── target ───────────────────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            implicitHeight: tcol.implicitHeight + 24
            radius: Theme.radius.card
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline
            ColumnLayout {
                id: tcol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                RowLayout {
                    spacing: 8
                    OIcon { icon: "web_asset"; size: 18; color: Theme.colors.accent }
                    OText {
                        Layout.fillWidth: true
                        text: root.appId !== "" ? root.appId : "Ninguna ventana enfocada: elige una app abajo"
                        font.family: root.appId !== "" ? Theme.font.mono : Theme.font.ui
                        size: 13.5
                        elide: Text.ElideRight
                    }
                }
                OText {
                    Layout.fillWidth: true
                    visible: root.winTitle !== ""
                    text: "«" + root.winTitle + "»"
                    size: 12
                    color: Theme.colors.textMuted
                    elide: Text.ElideRight
                }
                Toggle {
                    Layout.fillWidth: true
                    visible: root.winTitle !== ""
                    text: "Solo ventanas con este título"
                    checked: root.matchTitle
                    onToggled: root.matchTitle = !root.matchTitle
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.otherApps.length > 1
                    Repeater {
                        model: root.otherApps
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool on: modelData.appId === root.appId
                            implicitWidth: chipText.implicitWidth + 20
                            implicitHeight: 26
                            radius: 13
                            color: on ? Theme.colors.accentSoft : Theme.colors.surface2
                            border.width: 1
                            border.color: Theme.colors.outline
                            OText {
                                id: chipText
                                anchors.centerIn: parent
                                text: chip.modelData.appId
                                size: 11.5
                                color: chip.on ? Theme.colors.accent : Theme.colors.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.appId = chip.modelData.appId;
                                    root.winTitle = chip.modelData.title;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── form ─────────────────────────────────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            columns: 2
            columnSpacing: 28
            rowSpacing: 10
            Toggle { Layout.fillWidth: true; text: "Abrir flotante"; checked: root.floating; onToggled: root.floating = !root.floating }
            Toggle { Layout.fillWidth: true; text: "Abrir maximizada"; checked: root.maximized; onToggled: root.maximized = !root.maximized }
            Toggle { Layout.fillWidth: true; text: "No darle el foco al abrir"; checked: root.noFocus; onToggled: root.noFocus = !root.noFocus }
            Toggle { Layout.fillWidth: true; text: "Ocultar en capturas"; checked: root.hideCaptures; onToggled: root.hideCaptures = !root.hideCaptures }
        }
        Field { Layout.topMargin: 12; Layout.leftMargin: 18; text: "Ancho al abrir" }
        Segmented {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            current: root.width_
            options: [{ id: "", label: "Automático" }, { id: "0.33333", label: "1/3" }, { id: "0.5", label: "1/2" },
                      { id: "0.66667", label: "2/3" }, { id: "1.0", label: "Completo" }]
            onPicked: id => root.width_ = id
        }
        Field { Layout.topMargin: 12; Layout.leftMargin: 18; text: "Esquinas" }
        Segmented {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            current: root.corners
            options: [{ id: "", label: "Las del tema" }, { id: "0", label: "Rectas" }, { id: "8", label: "8 px" },
                      { id: "12", label: "12 px" }, { id: "20", label: "20 px" }]
            onPicked: id => root.corners = id
        }
        Field { Layout.topMargin: 12; Layout.leftMargin: 18; visible: root.namedWorkspaces.length > 0; text: "Espacio al abrir" }
        Segmented {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            visible: root.namedWorkspaces.length > 0
            current: root.workspace
            options: [{ id: "", label: "El actual" }].concat(root.namedWorkspaces.slice(0, 4).map(n => ({ id: n, label: n })))
            onPicked: id => root.workspace = id
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 12
            Field { text: "Opacidad" }
            OSlider {
                Layout.fillWidth: true
                icon: "opacity"
                value: root.opacity_
                step: 0.05
                onMoved: v => root.opacity_ = Math.max(0.3, v)
            }
        }

        // preview + save
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            implicitHeight: preview.implicitHeight + 20
            radius: Theme.radius.control
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline
            OText {
                id: preview
                anchors.fill: parent
                anchors.margins: 10
                text: root.kdl !== "" ? root.kdl : "Elige al menos una opción: la regla aparecerá aquí."
                font.family: root.kdl !== "" ? Theme.font.mono : Theme.font.ui
                size: 12
                color: root.kdl !== "" ? Theme.colors.text : Theme.colors.textDim
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.leftMargin: 18
            Layout.rightMargin: 14
            spacing: 10
            OText {
                Layout.fillWidth: true
                text: root.status
                size: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                color: root.failed ? Theme.colors.accent : Theme.colors.textMuted
            }
            OButton {
                text: "Guardar regla"
                icon: "check"
                primary: true
                enabled: root.kdl !== "" && !applier.running
                opacity: enabled ? 1 : 0.45
                onClicked: root.addRule()
            }
        }

        // ── existing rules ───────────────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; Layout.topMargin: 12; Layout.preferredHeight: 1; color: Theme.colors.outline }
        OText {
            Layout.topMargin: 10
            Layout.leftMargin: 18
            text: (root.rules.length > 0 ? "REGLAS CREADAS · " + root.rules.length : "AÚN NO HAY REGLAS")
            size: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            color: Theme.colors.textDim
        }
        Repeater {
            model: root.rules
            delegate: RowLayout {
                id: rr
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 12
                Layout.topMargin: 6
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    OText { Layout.fillWidth: true; text: rr.modelData.label; font.family: Theme.font.mono; size: 12.5; elide: Text.ElideRight }
                    OText { Layout.fillWidth: true; text: rr.modelData.summary; size: 11.5; color: Theme.colors.textMuted; elide: Text.ElideRight }
                }
                IconButton {
                    icon: "delete"
                    label: "Borrar regla"
                    danger: true
                    enabled: !applier.running
                    opacity: enabled ? 1 : 0.45
                    onClicked: root.removeRule(rr.index)
                }
            }
        }
        Item { Layout.preferredHeight: 12 }
    }
}
