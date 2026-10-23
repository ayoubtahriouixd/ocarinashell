pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services
import qs.modules.shima

// 広場 · music, big: 128 px cover (the card is tinted with its darkest strong colour), live equaliser, title,
// artist, progress (MPRIS position ticked once a second, only while playing and open), shuffle · ‹ · ▶ · › · repeat,
// and where it plays. Nothing playing: an invitation instead of an empty card.
HbCard {
    id: root
    readonly property var p: Media.player
    ColorQuantizer {
        id: quant
        source: Media.artUrl
        depth: 2
        rescaleSize: 64
    }
    readonly property color tint: {
        let best = Qt.rgba(0.11, 0.23, 0.36, 1), bestL = 2;
        for (const c of quant.colors) {
            const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
            if (l < bestL && l > 0.03) { best = c; bestL = l; }
        }
        const k = Math.min(1, 0.28 / Math.max(0.01, bestL));
        return Qt.rgba(best.r * k, best.g * k, best.b * k, 1);
    }
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0; color: Media.active ? Theme.mix(root.tint, Theme.colors.island, 0.45) : Theme.colors.islandCard }
        GradientStop { position: 0.75; color: Theme.colors.islandCard }
    }

    property real position: 0
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && Media.playing && (root.p?.positionSupported ?? false)
        onTriggered: root.position = root.p ? root.p.position : 0
    }
    readonly property real length: root.p?.length ?? 0
    function clock(s: real): string {
        s = Math.max(0, Math.round(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    ColumnLayout {
        visible: Media.active
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0
        RowLayout {
            spacing: 14
            Item {
                implicitWidth: 128
                implicitHeight: 128
                // the vinyl peeking from behind the cover: spins only while playing and visible (render thread)
                Rectangle {
                    id: vinyl
                    visible: Settings.data.hiroba.anime && Settings.data.hiroba.vinyl
                    x: 52
                    y: 4
                    width: 120
                    height: 120
                    radius: 60
                    color: "#161616"
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: 112 - index * 14
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: "#24ffffff"
                        }
                    }
                    Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15; color: Theme.colors.accent }
                    Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: "#111111" }
                    Rectangle { x: 62; y: 24; width: 3; height: 20; radius: 1.5; color: "#30ffffff"; rotation: 30 }   // a glint so the spin shows
                    RotationAnimator on rotation {
                        // from where it stopped: a pause does not snap the record back to 0°
                        from: vinyl.rotation % 360
                        to: vinyl.rotation % 360 + 360
                        duration: 1800             // 33⅓ rpm feel
                        loops: Animation.Infinite
                        running: vinyl.visible && Media.playing && root.visible && Motion.enabled && !Modes.shinobi
                    }
                }
            ClippingRectangle {
                anchors.fill: parent
                radius: 18
                color: Theme.alpha(root.tint, 1)
                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    sourceSize: Qt.size(256, 256)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                OIcon {
                    anchors.centerIn: parent
                    visible: Media.artUrl === ""
                    icon: "music_note"
                    size: 44
                    color: Theme.colors.islandMuted
                }
            }
            }
            Equalizer {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 4
                running: Media.playing && root.visible && !Modes.shinobi
                scale: 2
                transformOrigin: Item.BottomLeft
                color: "#f6e9c9"
            }
        }
        OText { Layout.topMargin: 14; Layout.fillWidth: true; text: Media.title || "—"; size: 16; font.weight: Font.DemiBold; color: Theme.colors.islandText }
        OText { Layout.fillWidth: true; text: Media.artist || (root.p?.identity ?? ""); size: 13; color: Theme.colors.islandMuted }
        Item {
            Layout.fillWidth: true
            Layout.topMargin: 12
            implicitHeight: 12
            visible: root.length > 0
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.colors.islandHover }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.min(1, root.position / Math.max(1, root.length))
                height: 4
                radius: 2
                color: Theme.colors.islandText
            }
            Rectangle {
                x: parent.width * Math.min(1, root.position / Math.max(1, root.length)) - 6
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6
                color: Theme.colors.knob
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: root.p?.canSeek ?? false
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    root.p.position = root.length * Math.max(0, Math.min(1, (m.x - 6) / parent.width));
                    root.position = root.p.position;
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 5
            visible: root.length > 0
            OText { text: root.clock(root.position); size: 11; color: Theme.colors.islandMuted; tabular: true }
            Item { Layout.fillWidth: true }
            OText { text: root.clock(root.length); size: 11; color: Theme.colors.islandMuted; tabular: true }
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            component Ctl: Item {
                id: c
                property string icon
                property real size: 24
                property bool dim: false
                property bool on: false
                signal hit
                implicitWidth: 36
                implicitHeight: 36
                OIcon {
                    anchors.centerIn: parent
                    icon: c.icon
                    fill: true
                    size: c.size
                    color: c.on ? Theme.colors.accent : c.dim ? Theme.colors.islandDim : Theme.colors.islandText
                }
                scale: ma.pressed ? 0.92 : 1
                MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.hit() }
                Accessible.role: Accessible.Button
                Accessible.name: c.icon
            }
            Ctl {
                icon: "shuffle"
                size: 20
                dim: !(root.p?.shuffle ?? false)
                on: root.p?.shuffle ?? false
                visible: root.p?.shuffleSupported ?? false
                onHit: root.p.shuffle = !root.p.shuffle
            }
            Item { Layout.fillWidth: true }
            Ctl { icon: "skip_previous"; onHit: Media.previous() }
            Rectangle {
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                implicitWidth: 52
                implicitHeight: 52
                radius: 26
                color: Theme.colors.islandText
                scale: pa.pressed ? 0.93 : 1
                Behavior on scale { Anim { ms: Motion.micro } }
                OIcon { anchors.centerIn: parent; icon: Media.playing ? "pause" : "play_arrow"; fill: true; size: 30; color: Theme.colors.island }
                MouseArea { id: pa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.playPause() }
                Accessible.role: Accessible.Button
                Accessible.name: Media.playing ? "Pausa" : "Reproducir"
            }
            Ctl { icon: "skip_next"; onHit: Media.next() }
            Item { Layout.fillWidth: true }
            Ctl {
                icon: (root.p?.loopState ?? 0) === MprisLoopState.Track ? "repeat_one" : "repeat"
                size: 20
                dim: (root.p?.loopState ?? 0) === MprisLoopState.None
                on: (root.p?.loopState ?? 0) !== MprisLoopState.None
                visible: root.p?.loopSupported ?? false
                onHit: root.p.loopState = root.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : root.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }
        RowLayout {
            Layout.topMargin: 10
            spacing: 6
            OIcon { icon: "speaker"; size: 15; color: Theme.colors.islandMuted }
            OText { Layout.fillWidth: true; text: Audio.sinkName + (root.p?.identity ? " · " + root.p.identity : ""); size: 11.5; color: Theme.colors.islandMuted }
        }
    }
    // 再生中 NOW PLAYING: a slanted red tag in the corner
    Item {
        visible: Media.active && Settings.data.hiroba.anime
        x: 12
        y: 12
        z: 3
        implicitWidth: tagRow.implicitWidth + 20
        implicitHeight: 22
        Rectangle {
            x: 2; y: 2
            width: parent.width; height: parent.height
            color: Theme.colors.island
            antialiasing: true
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.21, 0, 4.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.colors.accent
            antialiasing: true
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.21, 0, 4.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
        Row {
            id: tagRow
            anchors.centerIn: parent
            spacing: 6
            Kanji { anchors.verticalCenter: parent.verticalCenter; text: Media.playing ? "再生中" : "一時停止"; size: 11; color: Theme.colors.accentInk }
            OText {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.playing ? "NOW PLAYING" : "PAUSED"
                size: 11
                font.weight: Font.ExtraBold
                font.italic: true
                font.letterSpacing: 11 * 0.08
                color: Theme.colors.accentInk
            }
        }
    }
    // nothing playing
    ColumnLayout {
        visible: !Media.active
        anchors.centerIn: parent
        spacing: 8
        Kanji { Layout.alignment: Qt.AlignHCenter; text: "音"; brush: true; size: 64; color: Theme.colors.islandDim; opacity: 0.6 }
        OText { Layout.alignment: Qt.AlignHCenter; text: "Nada suena ahora"; size: 14; font.weight: Font.DemiBold; color: Theme.colors.islandText }
        OText { Layout.alignment: Qt.AlignHCenter; text: "Pon música y aparecerá aquí"; size: 12; color: Theme.colors.islandMuted }
    }
}
