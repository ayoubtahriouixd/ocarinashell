pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.components

// One Kura entry: text (two lines, masked when it looks like a secret) or image (thumbnail + format · size ·
// weight); pinned entries carry a red pin. Same language as Torii's rows: selected = surface2 + glowing red bar.
// Pin and delete buttons appear on the selected or hovered row.
Item {
    id: root
    required property var entry          // { pinned, kind: "text"|"image", text, thumb, meta, secret, item|pinIndex }
    required property int index
    property bool selected: false
    property bool revealed: false
    signal activated(bool paste)
    signal pinToggled
    signal removed
    signal hovered

    readonly property real headH: entry.head ? 30 : 0
    implicitHeight: headH + (entry.kind === "image" ? 108 : 58)

    // group header, as Torii's (11 px caps, dim)
    OText {
        visible: root.headH > 0
        x: 18
        y: 8
        text: (root.entry.head ?? "").toUpperCase()
        size: 11
        font.letterSpacing: 1
        font.weight: Font.DemiBold
        color: Theme.colors.textDim
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: root.headH
    }
    Rectangle {
        anchors.fill: body
        color: root.selected ? Theme.colors.surface2 : hov.hovered ? Theme.alpha(Theme.colors.surface2, 0.5) : "transparent"
    }
    SoftShadow {
        visible: root.selected
        target: bar
        offsetY: 0
        blur: 12
        steps: 3
        color: Theme.alpha(Theme.colors.accent, 0.6)
    }
    Rectangle {
        id: bar
        visible: root.selected
        y: body.y + 10
        width: 3
        height: body.height - 20
        radius: 1.5
        color: Theme.colors.accent
    }

    RowLayout {
        anchors.fill: body
        anchors.leftMargin: 18
        anchors.rightMargin: 12
        spacing: 12

        // the same 36 px icon tile on every row keeps one text column (mock.css .res)
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 11
            radius: 11
            color: Theme.alpha(Theme.colors.text, 0.08)
            OIcon {
                anchors.centerIn: parent
                icon: root.entry.kind === "image" ? "image" : root.entry.secret ? "key" : "notes"
                size: 20
                color: root.entry.secret ? Theme.colors.accent : Theme.colors.textMuted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            // image: thumbnail in the text column (ClippingRectangle: the picture gets the rounded corners too)
            ClippingRectangle {
                visible: root.entry.kind === "image"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 68
                radius: Theme.radius.control
                color: Theme.colors.surface3
                Image {
                    anchors.fill: parent
                    source: root.entry.kind === "image" ? root.entry.thumb : ""
                    sourceSize: Qt.size(240, 136)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }
            OText {
                Layout.fillWidth: true
                visible: root.entry.kind === "text"
                text: root.entry.secret && !root.revealed ? "••••••••••••" : root.entry.text.replace(/\s+/g, " ")
                textFormat: Text.PlainText
                size: 13.5
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            OText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.entry.kind === "image" ? root.entry.meta
                    : root.entry.secret ? "Oculto · parece una contraseña" : ""
                size: 12
                color: Theme.colors.textMuted
            }
        }

        // pinned mark / actions
        OIcon {
            visible: root.entry.pinned && !actions.visible
            icon: "push_pin"
            fill: true
            size: 16
            color: Theme.colors.accent
        }
        Row {
            id: actions
            visible: root.selected || hov.hovered
            spacing: 2
            IconButton {
                visible: root.entry.secret
                icon: root.revealed ? "visibility_off" : "visibility"
                label: root.revealed ? "Ocultar" : "Mostrar"
                onClicked: root.revealed = !root.revealed
            }
            IconButton {
                visible: !root.entry.secret             // secrets are never pinned (pins.json is a plain file)
                icon: "push_pin"
                danger: root.entry.pinned               // pinned = red pin, the same state everywhere
                label: root.entry.pinned ? "Soltar" : "Fijar"
                onClicked: root.pinToggled()
            }
            IconButton {
                icon: "close"
                label: "Borrar"
                danger: true
                onClicked: root.removed()
            }
        }
    }
    HoverHandler {
        id: hov
        onHoveredChanged: if (hovered) root.hovered()
    }
    // behind the row: the pin/delete buttons on top take their own clicks
    MouseArea {
        anchors.fill: body
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated(false)
    }
}
