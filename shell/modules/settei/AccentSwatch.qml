import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.config
import qs.components

// Accent choice (mock.css .acc): 34 × 34 radius 11 swatch, its traditional name below in `display` 13/600.
// Selected = 2 px surface0 gap + 2 px `text` ring. `rainbow` draws the conic «from the wallpaper» swatch.
ColumnLayout {
    id: root
    property color swatch: "#e60033"
    property string name
    property string hint: ""
    property bool rainbow: false
    property bool selected: false
    signal picked
    spacing: 6

    // the swatch is the focusable part, so the keyboard ring (FocusRing) wraps it, 3 px outside the selected ring
    Item {
        id: box
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 34
        implicitHeight: 34
        activeFocusOnTab: true
        Keys.onReturnPressed: root.picked()
        Keys.onSpacePressed: root.picked()
        Accessible.role: Accessible.RadioButton
        Accessible.name: "Acento " + (root.hint || root.name)
        Accessible.checked: root.selected
        FocusRing {
            anchors.margins: -7
            radius: 18
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 15
            visible: root.selected
            color: Theme.colors.text
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 13
                color: Theme.colors.surface0
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 11
            visible: !root.rainbow
            color: root.swatch
            scale: area.pressed ? 0.94 : 1
            Behavior on scale { Anim { ms: Motion.micro } }
        }
        Shape {
            anchors.fill: parent
            visible: root.rainbow
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: ConicalGradient {
                    centerX: 17
                    centerY: 17
                    angle: 60
                    GradientStop { position: 0.0; color: "#e60033" }
                    GradientStop { position: 0.2; color: "#e6b422" }
                    GradientStop { position: 0.4; color: "#68be8d" }
                    GradientStop { position: 0.6; color: "#00a3af" }
                    GradientStop { position: 0.8; color: "#7058a3" }
                    GradientStop { position: 1.0; color: "#e60033" }
                }
                PathRectangle { x: 0; y: 0; width: 34; height: 34; radius: 11 }
            }
        }
        OIcon {
            anchors.centerIn: parent
            visible: root.rainbow
            icon: "wallpaper"
            size: 15
            opacity: 0.75
            color: Theme.colors.onImage
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked()
        }
    }
    Kanji {
        Layout.alignment: Qt.AlignHCenter
        text: root.name
        size: 13
        lineHeightMode: Text.FixedHeight
        lineHeight: 13                       // mock.css: line-height 1 (Shippori's own box is much taller)
        Layout.topMargin: -3                 // Shippori's glyphs sit ~3 px low in that box (visual QA fase 17: +3,4)
        font.weight: Font.DemiBold
        color: root.selected ? Theme.colors.text : Theme.colors.textMuted
    }
}
