pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · the clock as an anime title card (mockup 16): a sky that follows the real time of day (night · dawn · day ·
// dusk, from Kisetsu's sunrise/sunset), stars at night, the moon or the sun, two layers of mountains, and the time in
// heavy italics with an ink outline and a red offset shadow; the date on a slanted red ribbon. Speed lines burst once
// when 広場 opens. Everything is static after that (repaints only on the minute tick).
Item {
    id: root
    property bool burst: false            // set by Hiroba when it finishes opening
    readonly property bool lines: Settings.data.hiroba.speedLines && Motion.enabled && !Modes.shinobi

    // time of day → palette
    readonly property real rise: Kisetsu.sunrise.getTime()
    readonly property real set_: Kisetsu.sunset.getTime()
    readonly property real now: Time.minute.getTime()
    readonly property string phase: {
        if (isNaN(rise) || isNaN(set_)) {
            const h = Time.now.getHours();
            return h < 6 || h >= 21 ? "night" : h < 8 ? "dawn" : h < 18 ? "day" : "dusk";
        }
        const hr = 3600000;
        if (now < rise - hr || now > set_ + hr) return "night";
        if (now < rise + hr) return "dawn";
        if (now > set_ - hr) return "dusk";
        return "day";
    }
    readonly property var sky: ({
        night: ["#0b0f2e", "#1c1748", "#4a1d4f", "#7a2340"],
        dawn: ["#2b2a5c", "#6b3c7a", "#e07a8a", "#f6c28b"],
        day: ["#1e5aa8", "#3f86d0", "#8cc3ea", "#cfe7f5"],
        dusk: ["#2a1a4a", "#7a2a5a", "#e0503a", "#f2a24a"]
    })[phase]
    readonly property var hills: phase === "day" ? ["#3c6e8f", "#22465e"] : phase === "night" ? ["#2a1438", "#14091d"]
        : ["#4a1f45", "#24102a"]

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.island.cardRadius
        border.width: 1
        border.color: Theme.colors.islandTrack
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.sky[0] }
            GradientStop { position: 0.45; color: root.sky[1] }
            GradientStop { position: 0.78; color: root.sky[2] }
            GradientStop { position: 1.0; color: root.sky[3] }
        }

        // everything that could reach a corner is clipped inside the curve (0.3·radius)
        Item {
            id: sky
            anchors.fill: parent
            anchors.margins: frame.radius * 0.3
            clip: true
        // speed lines: one burst when 広場 opens (rays around the centre, fade out)
        Item {
            id: rays
            anchors.centerIn: parent
            width: parent.width * 1.6
            height: width
            opacity: 0
            visible: false
            Repeater {
                model: 40
                delegate: Rectangle {
                    required property int index
                    x: rays.width / 2 - 1
                    y: rays.height / 2 - rays.height / 2
                    width: index % 3 === 0 ? 2.2 : 1.2
                    height: rays.height / 2 - 70
                    color: "#ffffff"
                    antialiasing: true
                    transform: Rotation { origin.x: 1; origin.y: rays.height / 2; angle: index * 9 + (index % 2) * 3 }
                }
            }
            SequentialAnimation {
                id: burstAnim
                ParallelAnimation {
                    OpacityAnimator { target: rays; from: 0; to: 0.28; duration: Motion.d(120) }
                    ScaleAnimator { target: rays; from: 0.85; to: 1.05; duration: Motion.d(520); easing.type: Easing.OutCubic }
                }
                OpacityAnimator { target: rays; from: 0.28; to: 0; duration: Motion.d(420) }
                ScriptAction { script: rays.visible = false }      // 40 rectangles out of the scene afterwards
            }
        }
        // stars (night and dawn)
        Repeater {
            model: root.phase === "night" ? 26 : root.phase === "dawn" ? 8 : 0
            delegate: Rectangle {
                required property int index
                // fixed pseudo-random positions (no Math.random: the sky must not change on every repaint)
                readonly property real fx: ((index * 73 + 17) % 97) / 97
                readonly property real fy: ((index * 41 + 29) % 53) / 53
                x: 8 + fx * (frame.width - 16)
                y: 6 + fy * frame.height * 0.5
                width: index % 5 === 0 ? 2.4 : 1.6
                height: width
                radius: width / 2
                color: "#ffffff"
                opacity: 0.35 + ((index * 7) % 10) / 15
            }
        }
        // the moon (night) or the sun (day/dawn/dusk), with a soft glow
        Rectangle {               // glow only for the sun (at night it banded into a grey disc)
            visible: root.phase !== "night"
            x: frame.width - 86
            y: root.phase === "dusk" ? 54 : 12
            width: 70; height: 70; radius: 35
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: root.phase === "night" ? "#30ffecbe" : "#40fff1b0" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {               // the sun
            visible: root.phase !== "night"
            x: frame.width - 86 + 18
            y: (root.phase === "dusk" ? 54 : 12) + 18
            width: 34; height: 34; radius: 17
            color: "#fff1b0"
        }
        Shape {                   // the crescent moon: the moon's left rim and, back up, the rim of a disc 10 px right
            visible: root.phase === "night"
            x: frame.width - 86 + 18
            y: 12 + 18
            width: 34; height: 34
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: "#fff3d6"
                startX: 22; startY: 0.75             // where the two 17 px circles (centres 10 px apart) cross
                PathArc { x: 22; y: 33.25; radiusX: 17; radiusY: 17; useLargeArc: true; direction: PathArc.Counterclockwise }
                PathArc { x: 22; y: 0.75; radiusX: 17; radiusY: 17; direction: PathArc.Clockwise }
            }
        }
        }
        // two layers of mountains (their bottom corners follow the card's radius)
        Shape {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 70
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.hills[0]
                PathPolyline {
                    readonly property real w: frame.width
                    path: [Qt.point(0, 52), Qt.point(w * .1, 30), Qt.point(w * .175, 44), Qt.point(w * .3, 14), Qt.point(w * .4, 40),
                           Qt.point(w * .5, 22), Qt.point(w * .625, 46), Qt.point(w * .75, 20), Qt.point(w * .875, 42), Qt.point(w, 28)]
                }
                PathLine { x: frame.width; y: 70 - frame.radius }
                PathArc { x: frame.width - frame.radius; y: 70; radiusX: frame.radius; radiusY: frame.radius }
                PathLine { x: frame.radius; y: 70 }
                PathArc { x: 0; y: 70 - frame.radius; radiusX: frame.radius; radiusY: frame.radius }
                PathLine { x: 0; y: 52 }
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.hills[1]
                PathPolyline {
                    readonly property real w: frame.width
                    path: [Qt.point(0, 62), Qt.point(w * .15, 44), Qt.point(w * .275, 58), Qt.point(w * .425, 36), Qt.point(w * .575, 60),
                           Qt.point(w * .725, 42), Qt.point(w * .875, 58), Qt.point(w, 46)]
                }
                PathLine { x: frame.width; y: 70 - frame.radius }
                PathArc { x: frame.width - frame.radius; y: 70; radiusX: frame.radius; radiusY: frame.radius }
                PathLine { x: frame.radius; y: 70 }
                PathArc { x: 0; y: 70 - frame.radius; radiusX: frame.radius; radiusY: frame.radius }
                PathLine { x: 0; y: 62 }
            }
        }

        // the title card: time · ribbon · date
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -4
            spacing: 10
            Item {
                // the Text box of a 76 px face is ~91 px tall for ~62 px of digits: lay out by the digits
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: clock.implicitWidth
                implicitHeight: Math.round(clock.font.pointSize / 0.75 * 0.86)
                Text {             // red offset «shadow» (4,4), anime title style
                    x: 4
                    y: clock.y + 4
                    text: clock.text
                    color: Theme.colors.accent
                    font: clock.font
                }
                Text {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(Time.minute, Time.h24 ? "HH:mm" : "h:mm")
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: "#1a0f2a"
                    font.family: Theme.font.ui
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pointSize: 76 * 0.75 * Theme.font.scale
                    font.letterSpacing: -76 * 0.03
                    font.features: { "tnum": 1 }
                }
            }
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: rib.implicitWidth + 28
                implicitHeight: 26
                Rectangle {
                    x: 3; y: 3
                    width: parent.width; height: parent.height
                    color: "#1a0f2a"
                    antialiasing: true
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.21, 0, 5.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colors.accent
                    antialiasing: true
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.21, 0, 5.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
                Kanji {
                    id: rib
                    anchors.centerIn: parent
                    text: Time.kanjiDate
                    color: "#ffffff"
                    size: 13
                    font.letterSpacing: 13 * 0.14
                }
            }
            OText {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.locale("es_ES").toString(Time.now, "dddd, d 'de' MMMM 'de' yyyy")
                size: 12.5
                font.weight: Font.DemiBold
                color: "#c8ffffff"
            }
        }
    }
    onBurstChanged: if (burst && root.lines) { rays.visible = true; burstAnim.restart(); }
}
