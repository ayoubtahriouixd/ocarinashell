pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "binds.js" as Binds

// 早見 Chuleta — every shortcut, read from niri's own binds.kdl (always in sync with the real config), grouped with
// kanji headers in three balanced columns, keys as on the Spanish keyboard, with a search box (Mod+Shift+').
PanelSurface {
    id: root
    implicitWidth: 1180
    implicitHeight: Math.min(col.implicitHeight, (QsWindow.window?.height ?? 1029) - 90)

    property var rows: []
    property string query: ""
    FileView {
        id: kdl
        path: Paths.niri + "/ocarina/binds.kdl"
        onLoaded: root.reparse()
        onLoadFailed: Health.fail("Chuleta", "no se pudo leer binds.kdl")
    }
    // your own keys (Ajustes › Atajos, bin/ocarina-binds)
    FileView {
        id: remapFile
        path: Paths.config + "/binds.json"
        printErrors: false
        onLoaded: root.reparse()
        onLoadFailed: root.reparse()
    }
    function reparse(): void {
        let remap = {};
        try {
            remap = JSON.parse(remapFile.text()).remap ?? {};
        } catch (e) {}
        root.rows = Binds.parse(kdl.text(), remap);
    }
    Component.onCompleted: field.forceActiveFocus()

    // the search only hides rows (visible: match), so typing never rebuilds the ~150 rows
    readonly property string q: query.trim().toLowerCase()
    function match(r: var): bool {
        return q === "" || r.title.toLowerCase().includes(q) || r.keys.concat(r.alts).join(" ").toLowerCase().includes(q);
    }
    // groups spread over 3 columns by row count (computed once, when binds.kdl is read)
    readonly property var columns: {
        const groups = Binds.groups().map(g => Object.assign({}, g, { rows: rows.filter(r => r.group === g.id) }))
            .filter(g => g.rows.length > 0);
        const cols = [[], [], []], load = [0, 0, 0];
        for (const g of groups) {
            const i = load.indexOf(Math.min(...load));
            cols[i].push(g);
            load[i] += g.rows.length + 2;
        }
        return cols;
    }
    readonly property int shown: rows.filter(r => root.match(r)).length

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ── header + search ──────────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            Layout.leftMargin: 20
            Layout.rightMargin: 16
            spacing: 12
            Kanji { text: "早見"; size: 22; color: Theme.colors.accent }
            OText { text: "Atajos de teclado"; size: 15; font.weight: Font.DemiBold }
            OText { text: root.shown + " atajos"; size: 12; color: Theme.colors.textMuted }
            Item { Layout.fillWidth: true }
            TextInput_ {
                id: field
                Layout.preferredWidth: 300
                implicitHeight: 36
                placeholder: "Busca una acción o una tecla"
                onTextChanged: root.query = text
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.colors.outline }

        // ── three columns of groups ──────────────────────────────────────────────────────────
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(grid.implicitHeight + 28, (QsWindow.window?.height ?? 1029) - 90 - 61 - 46)
            contentHeight: grid.implicitHeight + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
                id: grid
                x: 20
                y: 14
                width: flick.width - 40
                spacing: 26
                Repeater {
                    model: root.columns
                    delegate: ColumnLayout {
                        id: column
                        required property var modelData
                        Layout.preferredWidth: 1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 16
                        Repeater {
                            model: column.modelData
                            delegate: ColumnLayout {
                                id: group
                                required property var modelData
                                Layout.fillWidth: true
                                visible: group.modelData.rows.some(r => root.match(r))
                                spacing: 2
                                RowLayout {
                                    spacing: 8
                                    Layout.bottomMargin: 4
                                    Kanji { text: group.modelData.kanji; size: 15; color: Theme.colors.textMuted }
                                    OText {
                                        text: group.modelData.title.toUpperCase()
                                        size: 11
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1
                                        color: Theme.colors.textDim
                                    }
                                }
                                Repeater {
                                    model: group.modelData.rows
                                    delegate: RowLayout {
                                        id: row
                                        required property var modelData
                                        visible: root.match(modelData)
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        spacing: 10
                                        OText {
                                            Layout.fillWidth: true
                                            text: row.modelData.title
                                            size: 12.5
                                            elide: Text.ElideRight
                                        }
                                        Row {
                                            spacing: 3
                                            Repeater {
                                                model: row.modelData.keys
                                                delegate: Kbd {
                                                    required property string modelData
                                                    text: modelData
                                                }
                                            }
                                            OText {
                                                visible: row.modelData.alts.length > 0
                                                anchors.verticalCenter: parent.verticalCenter
                                                leftPadding: 4
                                                text: "/ " + row.modelData.alts.join(" / ")
                                                size: 11.5
                                                color: Theme.colors.textMuted
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // rows that continue below fade out instead of being cut
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            Rectangle {
                y: -28
                width: parent.width
                height: 28
                visible: flick.contentY + flick.height < flick.contentHeight - 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Theme.alpha(Theme.colors.surface0, 0.9) }
                }
            }
        }
        // ── footer ───────────────────────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.colors.outline }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            OText { text: "Super es la tecla de Windows · leído de ~/.config/niri/ocarina/binds.kdl"; size: 12; color: Theme.colors.textMuted }
            Item { Layout.fillWidth: true }
            OText { text: "早見 · Super+Shift+'"; font.family: Theme.font.jp; size: 12; color: Theme.colors.textMuted }
        }
    }
}
