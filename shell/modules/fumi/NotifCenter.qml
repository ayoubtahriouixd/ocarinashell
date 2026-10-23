pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// 文 Notification centre (Mod+Shift+N): history grouped by application, newest first; clear all; Do-not-disturb
// switch with its schedule. Opening it marks everything as read (the bell dot goes away).
PanelSurface {
    id: root
    implicitWidth: 420
    implicitHeight: Math.min(720, col.implicitHeight + 32)

    Component.onCompleted: Notifs.markRead()

    readonly property var groups: {
        const g = [];
        const index = {};
        for (const n of Notifs.history) {
            if (!(n.app in index)) {
                index[n.app] = g.length;
                g.push({ app: n.app, icon: n.icon, items: [] });
            }
            g[index[n.app]].items.push(n);
        }
        return g;
    }

    function ago(t: real): string {
        const m = Math.round((Date.now() - t) / 60000);
        if (m < 1) return "ahora";
        if (m < 60) return "hace " + m + " min";
        const h = Math.round(m / 60);
        if (h < 24) return "hace " + h + " h";
        return Qt.formatDate(new Date(t), "d MMM");
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Kanji { text: "文"; size: 22; color: Theme.colors.accent }
            OText { Layout.fillWidth: true; text: "Notificaciones"; size: 15; font.weight: Font.DemiBold }
            OText { text: "No molestar"; size: 12; color: Theme.colors.textMuted }
            Switch_ {
                checked: Notifs.dnd
                onToggled: Notifs.setDnd("toggle")
            }
        }
        OText {
            visible: Notifs.scheduleActive
            text: "No molestar por horario hasta las " + (Settings.data.notifications.dndSchedule?.to ?? "")
            size: 12
            color: Theme.colors.textMuted
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(560, list.implicitHeight)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: list
                width: parent.width
                spacing: 12

                ColumnLayout {
                    visible: Notifs.history.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 30
                    Layout.bottomMargin: 30
                    spacing: 6
                    Kanji { Layout.alignment: Qt.AlignHCenter; text: "静"; size: 48; opacity: 0.25 }
                    OText { Layout.alignment: Qt.AlignHCenter; text: "Sin notificaciones"; color: Theme.colors.textMuted }
                }

                Repeater {
                    model: root.groups
                    delegate: ColumnLayout {
                        id: grp
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        OText {
                            text: grp.modelData.app + (grp.modelData.items.length > 1 ? " · " + grp.modelData.items.length : "")
                            textFormat: Text.PlainText
                            size: 12
                            font.weight: Font.DemiBold
                            color: Theme.colors.textMuted
                        }
                        Repeater {
                            model: grp.modelData.items.slice(0, 5)
                            delegate: Rectangle {
                                id: item
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: body.implicitHeight + 20
                                radius: 14
                                color: Theme.colors.surface1
                                border.width: 1
                                border.color: item.modelData.urgency === "critical" ? Theme.colors.accent : Theme.colors.outline
                                // a click (or Enter) takes you to it (its window, its action or its app); the × (or
                                // Supr) only removes it
                                activeFocusOnTab: true
                                Keys.onReturnPressed: Notifs.openHistory(item.modelData)
                                Keys.onEnterPressed: Notifs.openHistory(item.modelData)
                                Keys.onDeletePressed: Notifs.removeHistory(item.modelData.uid)
                                Accessible.role: Accessible.Button
                                Accessible.name: grp.modelData.app + ": " + item.modelData.summary
                                Accessible.description: "Intro para abrir, Supr para borrar"
                                FocusRing {}
                                MouseArea {
                                    id: go
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Notifs.openHistory(item.modelData)
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Theme.colors.text
                                    opacity: go.containsMouse ? 0.04 : 0
                                }
                                ColumnLayout {
                                    id: body
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        OText { Layout.fillWidth: true; text: item.modelData.summary; size: 13; font.weight: Font.DemiBold; textFormat: Text.PlainText }
                                        OText { text: root.ago(item.modelData.time); size: 11; color: Theme.colors.textDim }
                                        IconButton {
                                            icon: "close"
                                            label: "Borrar notificación"
                                            onClicked: Notifs.removeHistory(item.modelData.uid)
                                        }
                                    }
                                    OText {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: item.modelData.body
                                        size: 12.5
                                        color: Theme.colors.textMuted
                                        textFormat: Text.StyledText
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Notifs.history.length > 0
            Item { Layout.fillWidth: true }
            OButton { text: "Borrar todo"; icon: "clear_all"; ghost: true; onClicked: Notifs.clearHistory() }
        }
    }
}
