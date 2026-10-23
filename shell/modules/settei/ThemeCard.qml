pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components

// Theme card (mock.css .tcard): a real miniature — the theme's own wallpaper with a mini bar and two windows in
// its colours — then kanji, name, light/dark and four swatches. Selected = 2 px accent border + 4 px accent-soft ring.
Item {
    id: root
    required property string themeId
    property bool selected: false
    signal picked
    property var t: null
    readonly property var c: t?.colors ?? ({})
    function col(k: string, fb: string): color {
        return Theme.qc(c[k], fb);
    }

    implicitHeight: 173
    FileView {
        path: Paths.asset("data/themes/" + root.themeId + ".json")
        printErrors: false
        onLoaded: {
            try { root.t = JSON.parse(text()); } catch (e) { root.t = null; }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 20
        visible: root.selected
        color: Theme.colors.accentSoft
    }
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius.card
        color: area.containsMouse && !root.selected ? Theme.colors.surface2 : Theme.colors.surface1
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Theme.colors.accent : Theme.colors.outline
        Behavior on color { CAnim {} }
        scale: area.pressed ? 0.985 : 1
        Behavior on scale { Anim { ms: Motion.micro } }

        ClippingRectangle {
            id: prev
            x: 8
            y: 8
            width: parent.width - 16
            height: 112
            radius: 10
            color: root.col("bg", "#000000")
            Image {
                anchors.fill: parent
                source: root.t ? Paths.url(Paths.wallpapers + "/" + root.t.wallpaper) : ""
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle { x: 6; y: 5; width: parent.width - 12; height: 10; radius: 4; color: root.col("surface0", "#141216"); opacity: 0.92 }
            Rectangle {
                x: 8; y: 21; width: parent.width * 0.44; height: parent.height - 29; radius: 5
                color: root.col("surface0", "#141216")
                border.width: 1.5
                border.color: root.col("accent", "#e60033")
            }
            Rectangle { x: parent.width * 0.51; y: 21; width: parent.width * 0.49 - 8; height: parent.height - 29; radius: 5; color: root.col("surface1", "#1b181d"); opacity: 0.95 }
            Rectangle { x: 12; y: 27; width: parent.width * 0.22; height: 4; radius: 2; color: root.col("accent", "#e60033") }
            Rectangle { x: 12; y: 35; width: parent.width * 0.34; height: 3; radius: 1.5; color: root.col("textMuted", "#aaa39b"); opacity: 0.6 }
        }
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 9
            spacing: 8
            Kanji {
                text: root.t?.kanji ?? ""
                size: 17
                color: root.col("accent", "#e60033")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                OText {
                    Layout.fillWidth: true
                    text: root.t?.name ?? root.themeId
                    size: Theme.font.body
                    font.weight: Font.DemiBold
                }
                OText {
                    Layout.fillWidth: true
                    text: root.t?.mode === "light" ? "claro" : "oscuro"
                    size: Theme.font.caption
                    color: Theme.colors.textMuted
                }
            }
            Row {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: -8                       // 14 px swatches overlapping by 4 inside their 2 px ring
                Repeater {
                    model: ["bg", "surface2", "accent", "accent2"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.colors.surface1
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            radius: 7
                            color: root.col(parent.modelData, "#000000")
                            border.width: 1
                            border.color: Theme.alpha(Theme.colors.text, 0.12)   // dark swatches on dark cards stay visible
                        }
                    }
                }
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
    activeFocusOnTab: true
    Keys.onReturnPressed: picked()
    Keys.onSpacePressed: picked()
    Accessible.role: Accessible.RadioButton
    Accessible.name: "Tema " + (t?.name ?? themeId)
    Accessible.checked: selected
    FocusRing { radius: 20 }
}
