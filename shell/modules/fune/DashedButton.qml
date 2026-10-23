import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

// «Añadir app» (mockup 09): 46 px tile with a dashed outline, muted icon and text.
Item {
    id: root
    property string text
    property string icon: "add"
    property bool active: false            // the add options are open
    signal clicked

    implicitHeight: 46
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.card
        color: area.containsMouse || root.active ? Theme.colors.surface2 : Theme.colors.surface1
        Behavior on color { CAnim {} }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: area.containsMouse || root.active ? Theme.colors.outlineStrong : Theme.colors.outline
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 2]                     // 1px dashed var(--outline): tone on tone
            fillColor: "transparent"
            PathRectangle {
                x: 0.5
                y: 0.5
                width: root.width - 1
                height: root.height - 1
                radius: Theme.radius.card
            }
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 8
        OIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.active ? "close" : root.icon
            size: 18
            color: Theme.colors.textMuted
        }
        OText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Theme.colors.textMuted
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
    Accessible.name: text
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    FocusRing {}
}
