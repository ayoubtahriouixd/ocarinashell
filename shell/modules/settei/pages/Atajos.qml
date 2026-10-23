pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settei
import "../../cheatsheet/binds.js" as Binds

// 技 Atajos: the same source as the cheat sheet (niri's binds.kdl, parsed by cheatsheet/binds.js) with your own keys
// on top (~/.config/ocarinashell/binds.json → bin/ocarina-binds → the validated include user-binds.kdl).
// Editing: the pencil of a row opens the editor under it: modifier chips + the main key pressed alone (niri keeps
// the combos it already has before they reach this window, so a combo cannot be «recorded» in one go).
SetteiPage {
    id: page
    subtitle: "Todos los atajos de niri. Cambia cualquiera con el lápiz; Super es la tecla de Windows."
    resetPaths: ["extras.iro", "extras.kaomoji"]
    readonly property string file: Paths.niri + "/ocarina/binds.kdl"
    readonly property string cli: Paths.bin + "/ocarina-binds"
    property var rows: []
    property var remap: ({})
    property string filter: ""
    property string editing: ""          // original combo of the row being edited
    readonly property int changedCount: Object.keys(remap).length

    headerRight: Component {
        RowLayout {
            spacing: 8
            OButton {
                visible: page.changedCount > 0
                ghost: true
                icon: "restart_alt"
                text: "Restaurar todos (" + page.changedCount + ")"
                onClicked: page.run(["reset-all"])
            }
            OButton {
                icon: "code"
                text: "Abrir en Neovim"
                onClicked: Quickshell.execDetached(["sh", "-c", 'command -v ghostty >/dev/null && exec ghostty +new-window -e nvim "$1" || exec xdg-open "$1"', "sh", page.file])
            }
        }
    }
    FileView {
        id: kdl
        path: page.file
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.reparse()
    }
    FileView {
        id: remapFile
        path: Paths.config + "/binds.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.reparse()
        onLoadFailed: page.reparse()
    }
    function reparse(): void {
        let r = {};
        try {
            r = JSON.parse(remapFile.text()).remap ?? {};
        } catch (e) {}
        remap = r;
        rows = Binds.parse(kdl.text(), r);
    }
    function norm(s: string): string {
        return (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }
    function match(r: var): bool {
        const q = norm(filter).trim();
        return q === "" || norm(r.title + " " + r.keys.join(" ")).indexOf(q) >= 0;
    }
    function titleOf(combo: string): string {
        const r = rows.find(x => x.combo === combo);
        return r ? r.title : combo;
    }

    // ── ocarina-binds ──
    property string error: ""
    property var conflict: null          // { with: combo, keys }
    property var lastArgs: []
    function run(args: var): void {
        if (proc.running)
            return;
        error = "";
        conflict = null;
        lastArgs = args;
        proc.command = [cli].concat(args);
        proc.running = true;
    }
    Process {
        id: proc
        stdout: StdioCollector { id: procOut }
        stderr: StdioCollector { id: procErr }
        onExited: code => {
            if (code === 0) {
                page.editing = "";
                Osd.show("info", 0, "Atajos actualizados", "keyboard");
            } else if (code === 3) {
                try {
                    const d = JSON.parse(procOut.text);
                    page.conflict = { with: d.conflict, keys: d.keys ?? "" };
                } catch (e) {
                    page.error = "Esas teclas ya están en uso";
                }
            } else {
                page.error = procErr.text.replace(/^ocarina-binds: /, "").trim().split("\n")[0] || ("código " + code);
            }
        }
    }

    TextInput_ {
        Layout.fillWidth: true
        Layout.topMargin: 18
        placeholder: "Filtrar atajos (p. ej. «captura», «Super+T»)…"
        onTextChanged: page.filter = text
    }
    Repeater {
        model: Binds.groups()
        delegate: ColumnLayout {
            id: grp
            required property var modelData
            readonly property var items: page.rows.filter(r => r.group === modelData.id && page.match(r))
            visible: items.length > 0
            Layout.fillWidth: true
            spacing: 4
            SectionTitle { text: grp.modelData.kanji + " · " + grp.modelData.title }
            Card {
                Layout.fillWidth: true
                Repeater {
                    model: grp.items
                    delegate: Column {
                        id: entry
                        required property var modelData
                        required property int index
                        // collapsed runs (Super+1…9) are edited in Neovim: one row stands for nine binds
                        readonly property bool editable: !modelData.run || modelData.runEnd === undefined
                        // the group's width, not the Column's parent: a positioner skips zero-width children, and
                        // this wrapper (row + editor) would stay 0 × 0 while the card settles
                        width: grp.width
                        SRow {
                            id: br
                            width: entry.width
                            separator: entry.index > 0
                            title: entry.modelData.title
                            minHeight: 42
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    visible: entry.modelData.changed
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: Theme.colors.accent
                                    Accessible.ignored: true
                                }
                                OText {
                                    visible: entry.modelData.off
                                    text: "sin atajo"
                                    size: 11.5
                                    color: Theme.colors.textMuted
                                }
                                Row {
                                    spacing: 3
                                    Repeater {
                                        model: entry.modelData.keys
                                        delegate: Kbd {
                                            required property string modelData
                                            text: modelData
                                        }
                                    }
                                    // the alternatives as keycaps too («/ Super M»), not plain text
                                    Repeater {
                                        model: entry.modelData.alts
                                        delegate: Row {
                                            id: alt
                                            required property string modelData
                                            spacing: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            OText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                leftPadding: 3
                                                rightPadding: 1
                                                text: "/"
                                                size: 11.5
                                                color: Theme.colors.textDim
                                            }
                                            Repeater {
                                                model: alt.modelData.split("+").filter(k => k !== "")
                                                delegate: Kbd {
                                                    required property string modelData
                                                    text: modelData
                                                }
                                            }
                                        }
                                    }
                                }
                                IconButton {
                                    visible: entry.editable
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    icon: page.editing === entry.modelData.combo ? "close" : "edit"
                                    label: page.editing === entry.modelData.combo ? "Cerrar el editor" : "Cambiar las teclas de «" + entry.modelData.title + "»"
                                    onClicked: {
                                        page.error = "";
                                        page.conflict = null;
                                        page.editing = page.editing === entry.modelData.combo ? "" : entry.modelData.combo;
                                    }
                                }
                            }
                        }
                        Loader {
                            width: entry.width
                            active: page.editing === entry.modelData.combo
                            visible: active
                            sourceComponent: BindEditor {
                                row: entry.modelData
                            }
                        }
                    }
                }
            }
        }
    }
    SectionTitle { text: "Herramientas con atajo" }
    Card {
        ToggleRow { title: "色 Iro · cuentagotas"; sub: "Super+Alt+P: color de cualquier píxel y el tradicional japonés más cercano"; key: "extras.iro" }
        ToggleRow { title: "顔 Kaomoji en Torii"; sub: "«:» busca kaomoji por palabra en español"; key: "extras.kaomoji" }
    }

    // ── the editor under a row ──
    component BindEditor: Rectangle {
        id: ed
        required property var row
        // the combo as niri spells it (effective keys; the original until changed)
        readonly property string current: page.remap[row.combo] !== undefined ? page.remap[row.combo] : row.combo
        readonly property var parts: current === "" ? [] : current.split("+")
        property var mods: ({ Mod: parts.includes("Mod") || parts.includes("Super"), Ctrl: parts.includes("Ctrl"),
                              Alt: parts.includes("Alt"), Shift: parts.includes("Shift") })
        property string key: parts.length > 0 ? parts[parts.length - 1] : ""
        readonly property string combo: ["Mod", "Ctrl", "Alt", "Shift"].filter(m => mods[m]).concat(key !== "" ? [key] : []).join("+")
        readonly property bool modOnly: key === ""

        implicitHeight: box.implicitHeight + 28
        color: Theme.colors.surface2
        border.width: 0
        Component.onCompleted: capture.forceActiveFocus()

        // Qt key → xkb keysym name (what niri reads); "" = not bindable from here
        function keysym(e: var): string {
            const k = e.key;
            if (k >= Qt.Key_A && k <= Qt.Key_Z)
                return String.fromCharCode(k);
            if (k >= Qt.Key_0 && k <= Qt.Key_9)
                return String.fromCharCode(k);
            if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
                return "F" + (k - Qt.Key_F1 + 1);
            const named = {};
            named[Qt.Key_Return] = "Return"; named[Qt.Key_Enter] = "KP_Enter"; named[Qt.Key_Space] = "space";
            named[Qt.Key_Tab] = "Tab"; named[Qt.Key_Left] = "Left"; named[Qt.Key_Right] = "Right";
            named[Qt.Key_Up] = "Up"; named[Qt.Key_Down] = "Down"; named[Qt.Key_Home] = "Home"; named[Qt.Key_End] = "End";
            named[Qt.Key_PageUp] = "Page_Up"; named[Qt.Key_PageDown] = "Page_Down"; named[Qt.Key_Insert] = "Insert";
            named[Qt.Key_Delete] = "Delete"; named[Qt.Key_Print] = "Print"; named[Qt.Key_Comma] = "Comma";
            named[Qt.Key_Period] = "Period"; named[Qt.Key_Minus] = "minus"; named[Qt.Key_Plus] = "plus";
            named[Qt.Key_Apostrophe] = "apostrophe"; named[Qt.Key_masculine] = "masculine";
            named[Qt.Key_Ntilde] = "ntilde"; named[Qt.Key_Ccedilla] = "ccedilla"; named[Qt.Key_Less] = "less";
            named[Qt.Key_exclamdown] = "exclamdown"; named[Qt.Key_Dead_Grave] = "dead_grave";
            named[Qt.Key_Dead_Acute] = "dead_acute"; named[Qt.Key_Dead_Diaeresis] = "dead_diaeresis";
            named[Qt.Key_Backspace] = "BackSpace";
            return named[k] ?? "";
        }

        ColumnLayout {
            id: box
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            spacing: 10

            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                // modifier chips: Space/Enter toggle them
                Repeater {
                    model: [{ id: "Mod", label: "Super" }, { id: "Ctrl", label: "Ctrl" }, { id: "Alt", label: "Alt" }, { id: "Shift", label: "Shift" }]
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool on: ed.mods[modelData.id] === true
                        function toggle(): void {
                            const m = Object.assign({}, ed.mods);
                            m[modelData.id] = !m[modelData.id];
                            ed.mods = m;
                        }
                        implicitWidth: chipLabel.implicitWidth + 22
                        implicitHeight: 30
                        radius: 10
                        color: on ? Theme.colors.accentSoft : chipArea.containsMouse ? Theme.colors.surface3 : Theme.colors.surface1
                        border.width: 1
                        border.color: on ? Theme.colors.accent : Theme.colors.outline
                        activeFocusOnTab: true
                        Keys.onSpacePressed: toggle()
                        Keys.onReturnPressed: toggle()
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: modelData.label
                        Accessible.checked: on
                        Behavior on color { CAnim {} }
                        OText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            size: 12
                            font.weight: Font.Medium
                            color: chip.on ? Theme.colors.accent : Theme.colors.text
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chip.toggle()
                        }
                        FocusRing {}
                    }
                }
                OText { text: "+"; color: Theme.colors.textMuted }
                // the main key, pressed alone
                Rectangle {
                    id: capture
                    implicitWidth: Math.max(150, capLabel.implicitWidth + 24)
                    implicitHeight: 30
                    radius: 10
                    color: Theme.colors.surface1
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.colors.accent : Theme.colors.outline
                    activeFocusOnTab: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Tecla principal: " + (ed.key || "ninguna")
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) {
                            page.editing = "";
                            e.accepted = true;
                            return;
                        }
                        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)
                            return;                       // keep Tab for moving between the controls
                        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R,
                             Qt.Key_AltGr].includes(e.key)) {
                            e.accepted = true;
                            return;
                        }
                        const k = ed.keysym(e);
                        if (k !== "") {
                            ed.key = k;
                            page.conflict = null;
                            page.error = "";
                        } else {
                            page.error = "Esa tecla no se puede asignar desde aquí (ábrelo en Neovim)";
                        }
                        e.accepted = true;
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: capture.forceActiveFocus()
                    }
                    OText {
                        id: capLabel
                        anchors.centerIn: parent
                        text: ed.key !== "" ? ed.key : capture.activeFocus ? "Pulsa una tecla…" : "Tecla"
                        size: 12
                        color: ed.key !== "" ? Theme.colors.text : Theme.colors.textMuted
                    }
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: 3
                    Repeater {
                        model: ed.modOnly ? [] : ed.combo.split("+").map(k => k === "Mod" ? "Super" : k)
                        delegate: Kbd {
                            required property string modelData
                            text: modelData
                        }
                    }
                }
            }

            // conflict / error
            RowLayout {
                visible: page.conflict !== null || page.error !== ""
                spacing: 10
                OIcon {
                    icon: "warning"
                    size: 16
                    color: Theme.colors.warning
                }
                OText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    size: 12
                    text: page.conflict ? "Ya lo usa «" + page.titleOf(page.conflict.with) + "». Si las tomas, ese atajo se queda sin teclas."
                                        : page.error
                }
                OButton {
                    visible: page.conflict !== null
                    text: "Tomarlas"
                    onClicked: page.run(["set", ed.row.combo, ed.combo, "--force"])
                }
            }

            RowLayout {
                spacing: 8
                OText {
                    Layout.fillWidth: true
                    text: "Original: " + ed.row.combo.replace(/^Mod\+/, "Super+") + " · Esc cierra"
                    size: 11.5
                    color: Theme.colors.textMuted
                }
                OButton {
                    visible: ed.row.changed
                    ghost: true
                    icon: "restart_alt"
                    text: "Restaurar"
                    onClicked: page.run(["reset", ed.row.combo])
                }
                OButton {
                    visible: !ed.row.off
                    ghost: true
                    icon: "block"
                    text: "Sin atajo"
                    onClicked: page.run(["disable", ed.row.combo])
                }
                OButton {
                    primary: true
                    enabled: !ed.modOnly && !proc.running && ed.combo !== ed.current
                    icon: "check"
                    text: proc.running ? "Validando…" : "Guardar"
                    onClicked: page.run(["set", ed.row.combo, ed.combo])
                }
            }
        }
    }
}
