import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.components

// One wallpaper in the Kabegami grid: 16:10 thumbnail radius 12, accent border when it is the current one, name and
// favourite on hover (the heart stays when it is a favourite), 季 season tags as a kanji chip in the top-left corner.
Item {
    id: root
    property url source
    property string name: ""
    property bool current: false
    property bool favorite: false
    property string seasonText: ""
    property bool showFavorite: true
    property bool busy: false
    property bool focused: false
    signal open
    signal favoriteToggled
    activeFocusOnTab: false
    Accessible.role: Accessible.Button
    Accessible.name: name + (current ? ", actual" : "") + (favorite ? ", favorito" : "") + (seasonText !== "" ? ", " + seasonText : "")

    Rectangle {
        anchors.fill: frame
        anchors.margins: -4
        radius: 16
        visible: root.current
        color: Theme.colors.accentSoft
    }
    Rectangle {
        visible: root.focused
        anchors.fill: frame
        anchors.margins: -4
        radius: 16
        color: "transparent"
        border.width: 2
        border.color: Theme.colors.accent
    }
    ClippingRectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: 6
        radius: 12
        color: Theme.colors.surface2
        border.width: root.current ? 2 : 1
        border.color: root.current ? Theme.colors.accent : Theme.colors.outline
        Image {
            id: img
            anchors.fill: parent
            source: root.source
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { Anim { ms: Motion.fast } }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 40
            opacity: area.containsMouse ? 1 : 0
            Behavior on opacity { Anim { ms: Motion.fast } }
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.colors.imageScrim }
            }
            OText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 9
                anchors.rightMargin: 36
                text: root.name
                size: 11.5
                color: Theme.colors.onImage
            }
        }
        Rectangle {
            visible: root.seasonText !== ""
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            width: seasonLabel.implicitWidth + 12
            height: 22
            radius: 11
            color: Theme.colors.imageChip
            Kanji {
                id: seasonLabel
                anchors.centerIn: parent
                text: root.seasonText
                size: 12
                color: Theme.colors.onImage
            }
        }
        Rectangle {
            visible: root.busy
            anchors.centerIn: parent
            width: 34
            height: 34
            radius: 17
            color: Theme.colors.imageScrim
            OIcon { anchors.centerIn: parent; icon: "downloading"; color: Theme.colors.onImage; size: 18 }
        }
    }
    MouseArea {
        id: area
        anchors.fill: frame
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
    }
    Rectangle {
        visible: root.showFavorite && (root.favorite || area.containsMouse || heart.containsMouse)
        anchors.right: frame.right
        anchors.bottom: frame.bottom
        anchors.margins: 6
        width: 28
        height: 28
        radius: 14
        color: Theme.colors.imageChip
        OIcon {
            anchors.centerIn: parent
            icon: "favorite"
            fill: root.favorite
            size: 16
            color: root.favorite ? Theme.colors.accentHover : Theme.colors.onImage
        }
        MouseArea {
            id: heart
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.favoriteToggled()
        }
    }
}
