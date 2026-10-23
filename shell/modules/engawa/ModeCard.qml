import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.engawa
import qs.components

// 忍 Shinobi / 鬼 Oni cards (mock.css .mode): 70 px; Shinobi = dashed red border, outlined brush hanko;
// Oni = black-on-red hanko with a gold rim, and when on a deep red gradient with a glow.
Item {
    id: root
    property string kind: "shinobi"
    property bool on: false
    signal clicked

    readonly property bool oni: kind === "oni"
    implicitHeight: 70

    SoftShadow {
        visible: root.oni && root.on
        target: card
        offsetY: 0
        blur: 52
        steps: 10
        color: Theme.alpha(Theme.colors.oni, 0.45)
    }
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius.card
        color: root.oni && root.on ? "transparent" : (area.containsMouse ? Theme.colors.surface2 : Theme.colors.surface1)
        border.width: root.oni ? 1 : 0
        border.color: root.on ? Theme.colors.oniEdge : Theme.colors.outline
        gradient: root.oni && root.on ? onGradient : null
        Gradient {
            id: onGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.colors.oni }
            GradientStop { position: 1.0; color: Theme.colors.oniDeep }
        }
    }
    // Shinobi: dashed accent border (1.5 px, dashes ≈ 3 / 2.3 logical as in the mockup), painted at device
    // resolution so it stays crisp at 1.75×
    Canvas {
        id: dash
        visible: !root.oni
        readonly property real k: QsWindow.window?.devicePixelRatio ?? 1.75
        width: parent.width * k
        height: parent.height * k
        scale: 1 / k
        transformOrigin: Item.TopLeft
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = Theme.alpha(Theme.colors.accent, root.on ? 0.95 : 0.65);
            ctx.lineWidth = 1.5 * k;
            ctx.setLineDash([2, 1.55]);       // in multiples of lineWidth
            const r = Theme.radius.card * k, w = width - ctx.lineWidth, h = height - ctx.lineWidth;
            ctx.beginPath();
            ctx.roundedRect(ctx.lineWidth / 2, ctx.lineWidth / 2, w, h, r, r);
            ctx.stroke();
        }
        onKChanged: requestPaint()
        Connections {
            target: Theme.colors
            function onAccentChanged() { dash.requestPaint(); }
        }
        Connections {
            target: root
            function onOnChanged() { dash.requestPaint(); }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 11
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 10
            color: root.oni ? Theme.colors.oni : (root.on ? Theme.colors.accent : "transparent")
            border.width: root.oni ? 2 : 1.5
            border.color: root.oni ? Theme.colors.oniGold : Theme.colors.accent
            Kanji {
                anchors.centerIn: parent
                brush: true
                text: root.oni ? "鬼" : "忍"
                size: 22
                color: root.oni ? Theme.colors.oniInk : (root.on ? Theme.colors.accentInk : Theme.colors.accent)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            OText {
                Layout.fillWidth: true
                text: root.oni ? "Oni" : "Shinobi"
                size: 13.5
                font.weight: Font.DemiBold
                color: root.oni && root.on ? Theme.colors.onImage : root.on ? Theme.colors.text : Theme.colors.textMuted
            }
            OText {
                Layout.fillWidth: true
                text: root.oni ? "Máx. potencia" : "Máx. batería"
                size: 11.5
                color: root.oni && root.on ? Theme.alpha(Theme.colors.onImage, 0.8) : Theme.colors.textMuted
            }
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
    Accessible.name: (oni ? "Oni, máxima potencia" : "Shinobi, máxima batería") + (on ? ", activo" : "")
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    FocusRing {}
}
