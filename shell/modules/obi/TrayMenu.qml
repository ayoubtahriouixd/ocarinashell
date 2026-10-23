pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

// Themed menu for a tray item (QsMenuOpener). Lives in a PopupWindow anchored under the icon; created only while
// open. Submenus open in place (one level is enough for tray apps; deeper ones fall back to the native menu).
Item {
    id: root

    required property Item anchorItem
    property var handle: null
    property bool shown: false

    function open(): void {
        if (handle)
            shown = true;
    }
    function close(): void {
        shown = false;
    }

    LazyLoader {
        active: root.shown
        PopupWindow {
            id: popup
            visible: true
            grabFocus: true
            color: "transparent"
            anchor.item: root.anchorItem
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 12
            anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
            implicitWidth: Math.max(200, col.implicitWidth + 12)
            implicitHeight: col.implicitHeight + 12
            onVisibleChanged: if (!visible) root.close()

            property var stack: [root.handle]
            property int selected: -1
            function back(): void {
                if (stack.length > 1) {
                    stack = stack.slice(0, -1);
                    selected = -1;
                } else {
                    root.close();
                }
            }
            function activate(entry: var): void {
                if (!entry || entry.isSeparator || !entry.enabled)
                    return;
                if (entry.hasChildren) {
                    stack = stack.concat([entry]);
                    selected = -1;
                } else {
                    entry.triggered();
                    root.close();
                }
            }
            function move(dir: int): void {
                const items = opener.children.values;
                let i = selected;
                for (let n = 0; n < items.length; n++) {
                    i = (i + dir + items.length) % items.length;
                    if (!items[i].isSeparator && items[i].enabled) {
                        selected = i;
                        return;
                    }
                }
            }

            QsMenuOpener {
                id: opener
                menu: popup.stack[popup.stack.length - 1]
            }

            Rectangle {
                anchors.fill: parent
                focus: true
                Keys.onPressed: ev => {
                    if (ev.key === Qt.Key_Down) popup.move(1);
                    else if (ev.key === Qt.Key_Up) popup.move(-1);
                    else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Right)
                        popup.activate(opener.children.values[popup.selected]);
                    else if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_Left) popup.back();
                    else return;
                    ev.accepted = true;
                }
                radius: Theme.radius.menu
                color: Theme.alpha(Theme.colors.surface1, Theme.glassOpaqueAlpha)
                border.width: 1
                border.color: Theme.colors.outline

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 0

                    // ‹ Atrás inside a submenu
                    Item {
                        visible: popup.stack.length > 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: backArea.containsMouse ? Theme.colors.surface2 : "transparent"
                        }
                        OText {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "‹ Atrás"
                            color: Theme.colors.textMuted
                        }
                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: popup.back()
                        }
                    }
                    Repeater {
                        model: opener.children
                        delegate: Item {
                            id: row
                            required property QsMenuEntry modelData
                            required property int index
                            Accessible.role: Accessible.MenuItem
                            Accessible.name: modelData.text.replace(/_(?!_)/g, "")
                            Layout.fillWidth: true
                            Layout.preferredHeight: modelData.isSeparator ? 9 : 30
                            implicitWidth: label.implicitWidth + 48

                            Rectangle {
                                visible: row.modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 12
                                height: 1
                                color: Theme.colors.outline
                            }
                            Rectangle {
                                visible: !row.modelData.isSeparator
                                anchors.fill: parent
                                radius: 8
                                color: (hov.containsMouse || popup.selected === row.index) && row.modelData.enabled
                                    ? Theme.colors.surface2 : "transparent"
                            }
                            OIcon {
                                visible: !row.modelData.isSeparator && row.modelData.buttonType !== QsMenuButtonType.None
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                size: 16
                                icon: row.modelData.buttonType === QsMenuButtonType.RadioButton
                                    ? (row.modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                                    : (row.modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                                color: row.modelData.checkState === Qt.Checked ? Theme.colors.accent : Theme.colors.textMuted
                            }
                            OText {
                                id: label
                                visible: !row.modelData.isSeparator
                                x: 30
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text.replace(/_(?!_)/g, "")
                                color: row.modelData.enabled ? Theme.colors.text : Theme.colors.textDim
                            }
                            OIcon {
                                visible: row.modelData.hasChildren
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "chevron_right"
                                size: 16
                                color: Theme.colors.textMuted
                            }
                            MouseArea {
                                id: hov
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !row.modelData.isSeparator && row.modelData.enabled
                                onClicked: popup.activate(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
