pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One app in the ocarina drawer: icon over its name (matched letters in red), 16 px tile. Selected = the accent at
// 12 % with a 1.5 px accent ring and a soft red glow; hover lifts the icon. `big` = the frequent row (52 px icons).
// The first time the drawer opens, tiles arrive in a short cascade (delay by index; nothing with motion reduced).
Item {
    id: root
    required property var app
    required property string html
    property bool selected: false
    property bool big: false
    property int cascade: -1                 // ≥ 0: index in the opening cascade
    signal activated
    signal menuRequested
    signal hovered

    readonly property bool pinned: Apps.isPinned(app.id)
    implicitWidth: big ? 108 : 104
    implicitHeight: big ? 112 : 96
    Accessible.role: Accessible.Button
    Accessible.name: app.name + (app.generic ? ", " + app.generic : "")

    Item {
        id: body
        anchors.fill: parent
        opacity: root.cascade >= 0 && Motion.enabled ? 0 : 1
        transform: Translate { id: lift; y: root.cascade >= 0 && Motion.enabled ? 8 : 0 }

        Rectangle {
            // glow under the selected tile
            visible: root.selected
            anchors.fill: tile
            anchors.margins: -3
            anchors.topMargin: -1
            anchors.bottomMargin: -6
            radius: Theme.radius.card + 3
            color: Theme.alpha(Theme.colors.accent, 0.12)
        }
        Rectangle {
            id: tile
            anchors.fill: parent
            anchors.margins: 3
            radius: Theme.radius.card
            color: root.selected ? Theme.alpha(Theme.colors.accent, 0.12)
                 : area.containsMouse ? Theme.colors.surface2 : "transparent"
            border.width: root.selected ? 1.5 : 0
            border.color: Theme.alpha(Theme.colors.accent, 0.7)
            Behavior on color { CAnim { ms: Motion.fast } }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: root.big ? 14 : 12
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: root.big ? 10 : 8
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.big ? 52 : 40
                    Layout.preferredHeight: root.big ? 52 : 40
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: root.big ? 52 : 40
                        asynchronous: true
                        source: Quickshell.iconPath(root.app.icon ?? "", "application-x-executable")
                        scale: area.containsMouse || root.selected ? 1.08 : 1
                        Behavior on scale { Anim { ms: Motion.fast } }
                    }
                    // 船 a Windows app (Fune)
                    Rectangle {
                        visible: root.app.fune
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -4
                        width: 18
                        height: 18
                        radius: 6
                        color: Theme.colors.asagi
                        Kanji {
                            anchors.centerIn: parent
                            text: "船"
                            size: 10
                            color: Theme.colors.surface0
                        }
                    }
                    // pinned: a small red seal
                    Rectangle {
                        visible: root.pinned
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: -3
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.colors.accent
                        border.width: 1.5
                        border.color: Theme.colors.surface1
                    }
                }
                OText {
                    Layout.fillWidth: true
                    text: root.html
                    textFormat: Text.StyledText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    size: Theme.font.meta
                    font.weight: root.selected ? Font.Medium : Font.Normal
                    color: root.selected || area.containsMouse ? Theme.colors.text : Theme.colors.textMuted
                }
                // the free height goes below: icons stay on one line whether the name takes one or two lines
                Item { Layout.fillHeight: true }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered()
            onClicked: ev => ev.button === Qt.RightButton ? root.menuRequested() : root.activated()
        }
    }

    // the opening cascade: Motion.drawer.stagger apart, at most cascadeDepth tiles deep (the rest arrive together)
    SequentialAnimation {
        running: root.cascade >= 0 && Motion.enabled
        PauseAnimation { duration: Motion.d(Math.max(0, Math.min(root.cascade, Motion.drawer.cascadeDepth)) * Motion.drawer.stagger) }
        ParallelAnimation {
            Anim { target: body; property: "opacity"; to: 1; ms: Motion.base }
            Anim { target: lift; property: "y"; to: 0; ms: Motion.slow; easing.bezierCurve: Motion.decel }
        }
    }
}
