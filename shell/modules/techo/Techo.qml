pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// 手帳 Techō — notes (Mod+N): panel on the right, full height. Tabs (one per note), plain-text editor with optional
// mincho type (Shippori Mincho) for writing "bonito", search across notes (ripgrep), word count and save state.
// Ctrl+T new note · Ctrl+F search · Ctrl+Tab next note · Esc closes (saved on every pause and on close).
PanelSurface {
    id: root
    implicitWidth: 480
    implicitHeight: (QsWindow.window?.height ?? 1029) - 66

    property bool searching: false
    property int foundSel: 0              // highlighted search result (↑↓ in the search field, hover)
    property bool confirmTrash: false
    readonly property bool mincho: Settings.data.techo.mincho
    // word count, recomputed 300 ms after typing stops (not on every keystroke)
    property int words: 0
    function count(): void {
        const t = editor.text.trim();
        words = t === "" ? 0 : t.split(/\s+/).length;
    }
    Timer {
        id: countTimer
        interval: 300
        onTriggered: root.count()
    }

    Component.onCompleted: {
        if (Notes.loaded)
            load();                       // reopened: the service already holds the note
        Notes.refresh();
    }
    Component.onDestruction: Notes.flush()

    // the editor is filled imperatively when a note is opened (a binding would fight with typing)
    Connections {
        target: Notes
        function onOpened() {
            root.load();
        }
        function onResultsChanged() {
            root.foundSel = 0;
        }
        function onAppended(line: string) {
            const c = editor.cursorPosition;
            editor.text = Notes.text;
            editor.cursorPosition = Math.min(c, editor.length);
        }
    }
    function load(): void {
        if (editor.text !== Notes.text)
            editor.text = Notes.text;
        editor.cursorPosition = editor.text.length;
        count();
        if (!searching)
            editor.forceActiveFocus();
    }
    function cycle(dir: int): void {
        const i = Notes.notes.findIndex(n => n.file === Notes.current);
        const n = Notes.notes.length;
        if (n > 0)
            Notes.open(Notes.notes[(i + dir + n) % n].file);
    }
    function toggleSearch(): void {
        searching = !searching;
        if (searching) {
            searchField.text = "";
            searchField.focusInput();             // the inner TextInput, not its frame
        } else {
            Notes.search("");
            editor.forceActiveFocus();
        }
    }

    // a search result → its note, and the search closes (click or Enter)
    function openFound(i: int): void {
        const r = Notes.results[i];
        if (!r)
            return;
        Notes.open(r.file);
        toggleSearch();
    }
    function moveFound(d: int): void {
        const n = Notes.results.length;
        if (n === 0)
            return;
        foundSel = Math.max(0, Math.min(n - 1, foundSel + d));
        found.positionViewAtIndex(foundSel, ListView.Contain);
    }

    Timer {
        id: trashTimer
        interval: 3000
        onTriggered: root.confirmTrash = false
    }

    // panel-wide shortcuts (the editor lets these through)
    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (ctrl && event.key === Qt.Key_T)
            Notes.create();
        else if (ctrl && event.key === Qt.Key_F)
            root.toggleSearch();
        else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab))
            root.cycle(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
        else
            return;
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── header ───────────────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 18
            Layout.rightMargin: 10
            spacing: 10
            Kanji { text: "手帳"; size: 22; color: Theme.colors.accent }
            OText { text: "Notas"; size: 15; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            OText {
                visible: root.confirmTrash
                text: "¿A la papelera? Pulsa otra vez"
                size: 12
                color: Theme.colors.accent
            }
            IconButton { icon: "search"; label: "Buscar en las notas (Ctrl+F)"; onClicked: root.toggleSearch() }
            // 明 mincho: serif type for writing
            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 11
                color: root.mincho ? Theme.colors.accentSoft : minHov.hovered ? Theme.colors.surface3 : Theme.colors.surface2
                Kanji {
                    anchors.centerIn: parent
                    text: "明"
                    size: 16
                    font.family: Theme.font.display
                    color: root.mincho ? Theme.colors.accent : Theme.colors.text
                }
                HoverHandler { id: minHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Settings.set("techo.mincho", !root.mincho) }
                Accessible.role: Accessible.Button
                Accessible.name: "Letra mincho"
            }
            IconButton { icon: "add"; label: "Nota nueva (Ctrl+T)"; onClicked: Notes.create() }
            IconButton {
                icon: "delete"
                label: "Mover la nota a la papelera"
                danger: true
                onClicked: {
                    if (root.confirmTrash) {
                        Notes.trash(Notes.current);
                        root.confirmTrash = false;
                    } else {
                        root.confirmTrash = true;
                        trashTimer.restart();
                    }
                }
            }
        }

        // ── tabs or search field ─────────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            ListView {
                id: tabs
                visible: !root.searching
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                model: Notes.notes
                currentIndex: Notes.notes.findIndex(n => n.file === Notes.current)
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: tab
                    required property var modelData
                    readonly property bool active: modelData.file === Notes.current
                    width: Math.min(170, label.implicitWidth + 24)
                    height: tabs.height
                    OText {
                        id: label
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 146)
                        text: tab.modelData.title
                        elide: Text.ElideRight
                        size: 13
                        font.weight: tab.active ? Font.DemiBold : Font.Normal
                        color: tab.active ? Theme.colors.text : Theme.colors.textMuted
                    }
                    Rectangle {
                        visible: tab.active
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16
                        height: 2
                        radius: 1
                        color: Theme.colors.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notes.open(tab.modelData.file)
                    }
                }
            }
            TextInput_ {
                id: searchField
                visible: root.searching
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                placeholder: "Buscar en todas las notas"
                onTextChanged: Notes.search(text)
                onAccepted: root.openFound(root.foundSel)
                // ↑↓ walk the results (the single-line TextInput lets them through); Enter opens (onAccepted)
                Keys.onPressed: ev => {
                    if (ev.key === Qt.Key_Down) root.moveFound(1);
                    else if (ev.key === Qt.Key_Up) root.moveFound(-1);
                    else if (ev.key === Qt.Key_PageDown) root.moveFound(5);
                    else if (ev.key === Qt.Key_PageUp) root.moveFound(-5);
                    else return;
                    ev.accepted = true;
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.colors.outline }
        }

        // ── search results ───────────────────────────────────────────────────────────────────
        ListView {
            id: found
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.searching
            clip: true
            model: Notes.results
            delegate: Item {
                id: res
                required property var modelData
                required property int index
                readonly property bool selected: root.foundSel === index
                width: found.width
                height: 58
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.title
                Accessible.description: modelData.line
                Accessible.selected: selected
                // one highlight for keyboard and hover, in the accent
                Rectangle {
                    anchors.fill: parent
                    color: res.selected ? Theme.alpha(Theme.colors.accent, 0.12) : "transparent"
                    Behavior on color { CAnim { ms: Motion.fast } }
                }
                Rectangle {
                    visible: res.selected
                    width: 2
                    height: parent.height
                    color: Theme.colors.accent
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 2
                    OText { Layout.fillWidth: true; text: res.modelData.title; size: 13.5; font.weight: Font.Medium; elide: Text.ElideRight }
                    OText { Layout.fillWidth: true; text: res.modelData.line; size: 12; color: Theme.colors.textMuted; elide: Text.ElideRight }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.foundSel = res.index
                    onClicked: root.openFound(res.index)
                }
            }
            OText {
                anchors.centerIn: parent
                visible: found.count === 0
                text: !Tools.has("rg") ? "Falta ripgrep (rg) para buscar"
                    : Notes.searchedFor.trim() === "" ? "Escribe para buscar" : "Nada coincide"
                size: 13
                color: Theme.colors.textMuted
            }
        }

        // ── editor ───────────────────────────────────────────────────────────────────────────
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.searching
            clip: true
            contentWidth: width
            contentHeight: editor.implicitHeight + 36
            boundsBehavior: Flickable.StopAtBounds
            // keep the caret visible while typing
            function ensureVisible(r: rect): void {
                if (contentY >= r.y - 18)
                    contentY = Math.max(0, r.y - 18);
                else if (contentY + height <= r.y + r.height + 18)
                    contentY = r.y + r.height + 18 - height;
            }
            TextEdit {
                id: editor
                x: 20
                y: 18
                width: flick.width - 40
                wrapMode: TextEdit.Wrap
                color: Theme.colors.text
                selectionColor: Theme.colors.accentSoft
                selectedTextColor: Theme.colors.text
                font.family: root.mincho ? Theme.font.display : Theme.font.ui
                font.pointSize: (root.mincho ? 16 : 15) * 0.75 * Theme.font.scale
                textFormat: TextEdit.PlainText
                persistentSelection: true
                cursorDelegate: Rectangle { width: 2; color: Theme.colors.accent }
                readOnly: !Notes.loaded           // never type into a note that is still loading
                onTextChanged: {
                    Notes.edit(text);
                    countTimer.restart();
                }
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                Keys.forwardTo: [root]
                OText {
                    visible: editor.text === ""
                    text: "Escribe… (la primera línea es el título)"
                    size: 15
                    color: Theme.colors.textDim
                }
            }
        }

        // ── footer ───────────────────────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.colors.outline }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            spacing: 10
            OText {
                text: root.words + (root.words === 1 ? " palabra" : " palabras") + " · " + editor.length + " caracteres"
                size: 12
                tabular: true
                color: Theme.colors.textMuted
            }
            OIcon {
                icon: Notes.dirty ? "pending" : "check_circle"     // saved locally (no cloud involved)
                size: 14
                color: Notes.dirty ? Theme.colors.textDim : Theme.colors.textMuted
            }
            OText { text: Notes.dirty ? "Guardando…" : "Guardado"; size: 12; color: Theme.colors.textMuted }
            Item { Layout.fillWidth: true }
            OText { text: "手帳 · Super+N"; font.family: Theme.font.jp; size: 12; color: Theme.colors.textMuted }
        }
    }
}
