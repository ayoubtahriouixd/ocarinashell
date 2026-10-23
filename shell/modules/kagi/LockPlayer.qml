pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Kagi's mini player (mockup 03, bottom-left): cover 44, title 13/600, artist 12, previous · play/pause · next.
// Media keys keep working while locked (allow-when-locked binds); this only mirrors and offers the same three actions.
Rectangle {
    id: root

    implicitWidth: Math.min(420, content.implicitWidth + 26)
    implicitHeight: 64
    radius: 18
    color: Theme.alpha(Theme.colors.surface0, 0.5)
    border.width: 1
    border.color: "#14ffffff"

    Row {
        id: content
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 12

        Rectangle {
            width: 44
            height: 44
            radius: 10
            color: Theme.colors.surface2
            clip: true
            OIcon {
                anchors.centerIn: parent
                icon: "music_note"
                size: 20
                color: Theme.colors.textMuted
                visible: cover.status !== Image.Ready
            }
            Image {
                id: cover
                anchors.fill: parent
                source: Media.artUrl
                sourceSize: Qt.size(88, 88)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(240, Math.max(titleText.implicitWidth, artistText.implicitWidth))
            spacing: 3
            OText {
                id: titleText
                width: parent.width
                text: Media.title || "Sin título"
                size: 13
                font.weight: Font.DemiBold
            }
            OText {
                id: artistText
                width: parent.width
                text: Media.artist
                size: 12
                color: Theme.colors.textMuted
                visible: text !== ""
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 10
            spacing: 4
            Repeater {
                model: [
                    { icon: "skip_previous", act: () => Media.previous(), name: "Anterior" },
                    { icon: Media.playing ? "pause" : "play_arrow", act: () => Media.playPause(), name: "Reproducir o pausar" },
                    { icon: "skip_next", act: () => Media.next(), name: "Siguiente" }
                ]
                delegate: Item {
                    id: btn
                    required property var modelData
                    required property int index
                    width: 32
                    height: 32
                    OIcon {
                        anchors.centerIn: parent
                        icon: btn.modelData.icon
                        fill: true
                        size: btn.index === 1 ? 22 : 18
                        opacity: ma.pressed ? 0.6 : 1
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.modelData.act()
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: btn.modelData.name
                }
            }
        }
    }
}
