pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.kura

// 蔵 Kura — clipboard history (Mod+V). Search · Iro's colours · pinned entries · cliphist history with image
// thumbnails. ↵ copies, Shift+↵ copies and pastes into the window that had the focus (wtype), Ctrl+P pins,
// Shift+Supr deletes, the sweep button wipes the history after a second press. Data: services/Clipboard.qml.
PanelSurface {
    id: root
    implicitWidth: 600
    implicitHeight: col.implicitHeight

    property string query: ""
    property int selected: 0
    property bool confirmWipe: false
    // the window that had the focus when Kura opened (a layer surface does not change niri's focused window)
    readonly property bool terminal: /ghostty|alacritty|kitty|foot|wezterm|konsole|terminal/i.test(Niri.focusedWindow?.app_id ?? "")

    // pins first, then the (filtered) history
    readonly property var entries: {
        const out = [];
        const q = query.trim();
        Clipboard.pins.forEach((p, i) => {
            if (q === "" || p.kind === "text" && p.text.toLowerCase().includes(q.toLowerCase()))
                out.push({ pinned: true, pinIndex: i, kind: p.kind, text: p.text ?? "", meta: p.meta ?? "",
                           thumb: p.kind === "image" ? "file://" + p.path : "", secret: false });
        });
        const pinned = out.length;
        for (const it of Clipboard.filter(q))
            out.push({ pinned: false, item: it, kind: it.image ? "image" : "text", text: it.text, meta: it.meta,
                       thumb: it.image ? Clipboard.thumb(it.id) : "", secret: it.secret });
        // group headers only when both groups are there
        if (pinned > 0 && out.length > pinned) {
            out[0].head = "固定 · Fijados";
            out[pinned].head = "履歴 · Historial";
        }
        return out;
    }
    onEntriesChanged: if (selected >= entries.length) selected = Math.max(0, entries.length - 1)
    onQueryChanged: selected = 0

    Component.onCompleted: {
        Clipboard.refresh();
        field.forceActiveFocus();
    }

    function activate(i: int, paste: bool): void {
        const e = entries[i];
        if (!e)
            return;
        if (e.pinned) {
            Clipboard.copyPin(Clipboard.pins[e.pinIndex]);
            if (paste)
                Quickshell.execDetached([Clipboard.helper, "paste", terminal ? "terminal" : ""]);
        } else if (paste || Settings.data.clipboard.pasteOnEnter) {
            Clipboard.copyAndPaste(e.item, terminal);
        } else {
            Clipboard.copy(e.item);
        }
        Panels.close();
    }
    function togglePin(i: int): void {
        const e = entries[i];
        if (!e)
            return;
        if (e.pinned)
            Clipboard.unpin(e.pinIndex);
        else
            Clipboard.pin(e.item);
    }
    function remove(i: int): void {
        const e = entries[i];
        if (!e)
            return;
        if (e.pinned)
            Clipboard.unpin(e.pinIndex);
        else
            Clipboard.remove(e.item);
    }

    Timer {
        id: wipeTimer
        interval: 3000
        onTriggered: root.confirmWipe = false
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // ── header: 蔵 + search + wipe ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 12
                spacing: 12
                Kanji { text: "蔵"; size: 24; color: Theme.colors.accent }
                TextInput {
                    id: field
                    Layout.fillWidth: true
                    color: Theme.colors.text
                    selectionColor: Theme.colors.accentSoft
                    font.family: Theme.font.ui
                    font.pointSize: 17 * 0.75 * Theme.font.scale
                    cursorDelegate: Rectangle { width: 2; color: Theme.colors.accent }
                    clip: true
                    onTextChanged: root.query = text
                    Keys.onPressed: event => {
                        const n = root.entries.length;
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.selected = Math.min(n - 1, root.selected + 1);
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            root.selected = Math.max(0, root.selected - 1);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.selected, (event.modifiers & Qt.ShiftModifier) !== 0);
                        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            root.togglePin(root.selected);
                        } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                            root.remove(root.selected);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                    OText {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Busca en el portapapeles"
                        size: 17
                        color: Theme.colors.textDim
                    }
                }
                OText {
                    visible: root.confirmWipe
                    text: "¿Vaciar? Pulsa otra vez"
                    size: 12
                    color: Theme.colors.accent
                }
                IconButton {
                    icon: "delete_sweep"
                    label: "Vaciar historial (los fijados se quedan)"
                    danger: true
                    onClicked: {
                        if (root.confirmWipe) {
                            Clipboard.wipe();
                            root.confirmWipe = false;
                        } else {
                            root.confirmWipe = true;
                            wipeTimer.restart();
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.colors.outline }
        }

        // ── 色 Iro: last picked colours ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 10
            visible: Clipboard.colors.length > 0
            spacing: 8
            Kanji { text: "色"; size: 13; color: Theme.colors.textMuted }
            Repeater {
                model: Clipboard.colors
                delegate: Rectangle {
                    id: sw
                    required property string modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: modelData
                    border.width: 1
                    border.color: Theme.colors.glassBorder
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Clipboard.copyColor(sw.modelData);
                            Panels.close();
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ── entries ──────────────────────────────────────────────────────────────────────────
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: Math.min(contentHeight, 560)
            visible: root.entries.length > 0
            clip: true
            model: root.entries
            currentIndex: root.selected
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            delegate: ClipRow {
                required property var modelData
                width: listView.width
                entry: modelData
                selected: index === root.selected
                onActivated: paste => root.activate(index, paste)
                onPinToggled: root.togglePin(index)
                onRemoved: root.remove(index)
                onHovered: root.selected = index
            }
        }

        // empty / loading
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 26
            Layout.bottomMargin: 20
            visible: root.entries.length === 0
            spacing: 6
            Kanji {
                Layout.alignment: Qt.AlignHCenter
                text: "空"
                size: 40
                color: Theme.colors.textDim
            }
            OText {
                Layout.alignment: Qt.AlignHCenter
                text: !Tools.has("cliphist") || !Tools.has("wl-copy") ? "Falta cliphist o wl-clipboard: instálalos con pacman"
                    : Clipboard.loading ? "Cargando…" : root.query !== "" ? "Nada coincide" : "El portapapeles está vacío"
                size: 13
                color: Theme.colors.textMuted
            }
        }

        // ── footer: keys ─────────────────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; Layout.preferredHeight: 1; color: Theme.colors.outline }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            spacing: 14
            KeyHint { keys: ["↵"]; text: "copiar" }
            KeyHint { keys: ["Shift", "↵"]; text: "pegar" }
            KeyHint { keys: ["Ctrl", "P"]; text: "fijar" }
            KeyHint { keys: ["Shift", "Supr"]; text: "borrar" }
            Item { Layout.fillWidth: true }
            OText { text: "蔵 · Super+V"; font.family: Theme.font.jp; size: 12; color: Theme.colors.textMuted }
        }
    }
}
