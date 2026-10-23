pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.torii

// 鳥居 Torii (mockup 04): 680 px glass panel. Field 60 px (torii, 24 px text, 2 px red caret, hint 探す), mode chips,
// grouped results, footer with keys. All search logic lives in services/Launcher.qml.
PanelSurface {
    id: root
    implicitWidth: 680
    implicitHeight: col.implicitHeight
    radius: Theme.radius.panel
    property alias input: field

    function focusInput(): void {
        field.forceActiveFocus();
        field.selectAll();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // ── field ────────────────────────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14
                ToriiGate {}
                TextInput {
                    id: field
                    Layout.fillWidth: true
                    text: Launcher.query
                    onTextEdited: Launcher.query = text
                    color: Theme.colors.text
                    selectionColor: Theme.colors.surface3     // a prefilled query is selected: neutral, not red
                    selectedTextColor: Theme.colors.text
                    font.family: Theme.font.ui
                    font.pointSize: 24 * 0.75 * Theme.font.scale
                    cursorDelegate: Rectangle {
                        width: 2
                        radius: 1
                        color: Theme.colors.accent
                        visible: field.cursorVisible
                    }
                    clip: true
                    Keys.onPressed: ev => {
                        const ctrl = (ev.modifiers & Qt.ControlModifier) !== 0;
                        const n = Launcher.results.length;
                        if (ev.key === Qt.Key_Down || (ctrl && ev.key === Qt.Key_J))
                            Launcher.selected = Math.min(n - 1, Launcher.selected + 1);
                        else if (ev.key === Qt.Key_Up || (ctrl && ev.key === Qt.Key_K))
                            Launcher.selected = Math.max(0, Launcher.selected - 1);
                        else if (ev.key === Qt.Key_Tab)
                            Launcher.cycleMode(1);
                        else if (ev.key === Qt.Key_Backtab)
                            Launcher.cycleMode(-1);
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter)
                            Launcher.activate(Launcher.selected, ctrl);
                        else if (ev.key === Qt.Key_Escape)
                            Launcher.hide();
                        else if (ctrl && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9)
                            Launcher.activate(ev.key - Qt.Key_1, false);
                        else
                            return;
                        ev.accepted = true;
                    }
                    OText {
                        visible: field.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Escribe para buscar…"
                        color: Theme.colors.textDim
                        size: 24
                    }
                }
                OText {
                    text: "探す · busca apps, archivos y ajustes"
                    font.family: Theme.font.jp
                    size: 13
                    font.weight: Font.Medium
                    color: Theme.colors.textDim
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.colors.outline }
        }

        // ── mode chips ───────────────────────────────────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 10
            Layout.bottomMargin: 6
            spacing: 6
            Repeater {
                // the six modes, plus a seventh chip while a prefix-only mode (@ windows, ~ SSH, ? web, ; Snake) is active,
                // so one chip is always lit
                model: {
                    const m = Launcher.parsed().mode;
                    const extra = { windows: { id: "windows", label: "Ventanas", icon: "select_window", prefix: "@" },
                                    ssh: { id: "ssh", label: "SSH", icon: "lan", prefix: "~" },
                                    web: { id: "web", label: "Web", icon: "travel_explore", prefix: "?" },
                                    snake: { id: "snake", label: "Snake", icon: "neurology", prefix: ";" } }[m];
                    return extra ? Launcher.modes.concat([extra]) : Launcher.modes;
                }
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: Launcher.parsed().mode === modelData.id
                    implicitHeight: 24
                    implicitWidth: chipRow.implicitWidth + 18
                    radius: 12
                    color: on ? Theme.colors.accentSoft : Theme.colors.surface2
                    border.width: on ? 0 : 1
                    border.color: Theme.colors.outline
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5
                        OIcon { icon: chip.modelData.icon; size: 16; color: chip.on ? Theme.colors.accent : Theme.colors.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        OText { text: chip.modelData.label; size: 11.5; font.weight: Font.Medium; color: chip.on ? Theme.colors.accent : Theme.colors.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    TapHandler {
                        onTapped: {
                            Launcher.mode = chip.modelData.id;
                            if ("/=:!>@~?".indexOf(Launcher.query.charAt(0)) >= 0)
                                Launcher.query = Launcher.query.slice(1);
                            Launcher.refresh();
                            root.focusInput();
                        }
                    }
                }
            }
        }

        // ── results ──────────────────────────────────────────────────────────────────────────
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 470)
            Layout.bottomMargin: 4
            model: Launcher.results
            reuseItems: true                      // rows are recycled while typing, not rebuilt
            currentIndex: Launcher.selected
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            section.property: "group"
            section.delegate: OText {
                required property string section
                width: ListView.view.width
                height: 30
                leftPadding: 18
                topPadding: 8
                text: section.toUpperCase()
                size: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                color: Theme.colors.textDim
            }
            delegate: ResultRow {
                required property var modelData
                width: ListView.view.width
                item: modelData
            }
        }

        // ── footer ───────────────────────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.colors.outline }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            spacing: 14
            KeyHint { keys: ["↑", "↓"]; text: "moverse" }
            KeyHint { keys: ["↵"]; text: "abrir" }
            KeyHint { keys: ["Tab"]; text: "modos" }
            KeyHint { keys: ["Esc"]; text: "cerrar" }
            Item { Layout.fillWidth: true }
            OText { text: "鳥居 · Super+A"; font.family: Theme.font.jp; size: 12; color: Theme.colors.textMuted }
        }
    }
}
