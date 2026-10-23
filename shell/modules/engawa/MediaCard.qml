pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// Media card (mockup 02): tinted with the dominant colour of the cover (ColorQuantizer), cover 56 (radius 12),
// title/artist, progress (only updated while visible), previous / play-pause / next.
Item {
    id: root
    implicitHeight: 80

    ColorQuantizer {
        id: quant
        source: Media.artUrl
        depth: 2
        rescaleSize: 64
    }
    // darkest saturated swatch → base of the gradient (white text must stay readable)
    readonly property color tint: {
        let best = Qt.rgba(0.12, 0.25, 0.4, 1);
        let bestL = 2;
        for (const c of quant.colors) {
            const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
            if (l < bestL && l > 0.03) {
                best = c;
                bestL = l;
            }
        }
        const k = Math.min(1, 0.32 / Math.max(0.01, bestL));     // keep it dark: luminance ≤ ~0.32
        return Qt.rgba(best.r * Math.min(1, k), best.g * Math.min(1, k), best.b * Math.min(1, k), 1);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.card
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.tint }
            GradientStop { position: 1.0; color: Theme.mix(root.tint, "#000000", 0.45) }
        }
    }

    // position is not reactive in MPRIS: tick it once a second, only while visible and playing
    property real position: 0
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && Media.playing && (Media.player?.positionSupported ?? false)
        triggeredOnStart: true
        onTriggered: root.position = Media.player ? Media.player.position : 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.1)
            clip: true
            Image {
                anchors.fill: parent
                source: Media.artUrl
                sourceSize: Qt.size(112, 112)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            // rounded corners over a gradient background: a ring of the card colour would not match, so the cover is
            // clipped by the parent rectangle (rectangular clip; radius 12 kept by the ring below)
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 13
                color: "transparent"
                border.width: 2
                border.color: root.tint
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            OText {
                Layout.fillWidth: true
                text: Media.title || "Sin título"
                size: 13.5
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
            OText {
                Layout.fillWidth: true
                text: Media.artist || (Media.player?.identity ?? "")
                size: 12
                color: Qt.rgba(1, 1, 1, 0.7)
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: 3
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.18)
                visible: (Media.player?.lengthSupported ?? false) && Media.player.length > 0
                Rectangle {
                    width: parent.width * Math.min(1, root.position / Math.max(1, Media.player?.length ?? 1))
                    height: 3
                    radius: 2
                    color: "#ffffff"
                }
            }
        }
        Repeater {
            model: [
                { icon: "skip_previous", act: () => Media.previous() },
                { icon: Media.playing ? "pause" : "play_arrow", act: () => Media.playPause() },
                { icon: "skip_next", act: () => Media.next() }
            ]
            delegate: OIcon {
                required property var modelData
                Accessible.role: Accessible.Button
                Accessible.name: ({ skip_previous: "Anterior", pause: "Pausa", play_arrow: "Reproducir", skip_next: "Siguiente" })[modelData.icon] ?? modelData.icon
                activeFocusOnTab: true
                Keys.onReturnPressed: modelData.act()
                Keys.onSpacePressed: modelData.act()
                FocusRing {}
                icon: modelData.icon
                fill: true
                size: 22
                color: "#ffffff"
                Layout.preferredWidth: 30
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.modelData.act()
                }
            }
        }
    }
}
