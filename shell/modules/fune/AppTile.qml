import QtQuick
import qs.config
import qs.components

// A Windows app in the Fune panel (mockup 09 .tile): 84 px, the app's own icon on a 38 px surface3 square
// (radius 12), name 12,5 underneath. Click opens it as a RemoteApp window (the VM resumes/boots by itself).
Rectangle {
    id: root
    property string name
    property string icon: ""
    property string glyph: "apps"          // Material fallback when the app has no icon
    signal clicked

    implicitHeight: 84
    radius: Theme.radius.card
    color: area.containsMouse ? Theme.colors.surface2 : Theme.colors.surface1
    border.width: 1
    border.color: Theme.colors.outline
    scale: area.pressed ? 0.97 : 1
    Behavior on color { CAnim {} }
    Behavior on scale { Anim { ms: Motion.micro } }

    Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 6
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 38
            height: 38
            radius: Theme.radius.menu
            color: Theme.colors.surface3
            Image {
                id: img
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: root.icon !== "" && status === Image.Ready
                source: root.icon !== "" ? "file://" + root.icon : ""
                sourceSize: Qt.size(48, 48)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }
            OIcon {
                anchors.centerIn: parent
                visible: !img.visible
                icon: root.glyph
                fill: true
                size: 20
                color: Theme.colors.asagi
            }
        }
        OText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.name
            size: Theme.font.small
            // two lines before the ellipsis: «Símbolo del sistema», «Explorador de archivos» (visual QA, fase 17)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            lineHeight: 0.92
            elide: Text.ElideRight
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Abrir " + name + " (Windows)"
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    FocusRing {}
}
