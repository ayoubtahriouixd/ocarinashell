pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Window
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 Hiroba — the island, opened (mockups 14/16; replaces Koyomi): you · the time · 招き猫 lucky cat / the month ·
// 七十二候 and weather · music / the machine. It lives in the panel host (click outside, Esc, one panel at a time)
// and is drawn as ink poured out of the island: under the bar (which stays, island included) a pill of the island's
// REAL size (Panels.island*, published by the bar) grows into the panel in 240 ms — or follows the finger when pulled
// down — then the rows fade in one after another. Closing: the contents fade, the ink shrinks back into the pill and
// fades, and only then the panel goes (`closed`).
// Cost: no layers or shaders. During the morph only rectangles change size; rounded corners come from shapes that
// are rounded themselves, and from clips inset by 0.3·radius (inside the curve). Sections switched off in Settei are
// not created; the sampler exists only with the machine row on screen.
Item {
    id: root
    readonly property real screenW: Window.window ? Window.window.width : 1646
    readonly property real screenH: Window.window ? Window.window.height : 1029
    implicitWidth: Math.min(Theme.island.panelWidth, screenW - 2 * Theme.bar.side)
    implicitHeight: Math.min(col.implicitHeight + 44, screenH - Theme.island.hirobaTop - 16)

    signal closed

    readonly property bool want: Panels.open === "hiroba"
    readonly property bool dragging: Panels.dragging === "hiroba"
    property real p: 0                    // 0 = the island's rectangle · 1 = the whole panel (may overshoot a little)
    property real cv: 1                   // contents visibility: on closing they go first, then the ink shrinks
    readonly property var sec: Settings.data.hiroba.sections

    // the island's rectangle, frozen when the morph starts (its live size changes as it hides)
    property real fromW: 210
    property real fromH: Theme.island.height
    property real fromR: Theme.island.height / 2
    function freeze(): void {
        fromW = Panels.islandW;
        fromH = Panels.islandH;
        fromR = Panels.islandR;
    }

    onWantChanged: {
        if (!want)
            arrived = false;
        run();
    }
    onDraggingChanged: if (!dragging) run()
    Connections {
        target: Panels
        function onDragProgressChanged() {
            if (!root.dragging)
                return;
            openAnim.stop();
            closeAnim.stop();
            root.cv = 1;
            shape.opacity = 1;
            root.p = Panels.dragProgress;
        }
    }
    function run(): void {
        if (dragging)
            return;
        if (!Motion.enabled) {
            p = want ? 1 : 0;
            cv = 1;
            Panels.hirobaClosing = false;
            if (!want)
                Qt.callLater(() => root.closed());   // after the panel host has seen `shown` go false
            return;
        }
        if (want) {
            closeAnim.stop();
            Panels.hirobaClosing = false;
            shape.opacity = 1;
            openAnim.restart();
        } else {
            openAnim.stop();
            Panels.hirobaClosing = true;
            closeAnim.restart();
        }
    }
    ParallelAnimation {
        id: openAnim
        // quick, like the closing (Ayoub): the ink reaches the panel in 240 ms, most of it in the first frames
        NumberAnimation {
            target: root
            property: "p"
            to: 1
            duration: Motion.d(Motion.hiroba.open)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.decel
        }
        NumberAnimation { target: root; property: "cv"; to: 1; duration: Motion.d(Motion.fast) }   // reopening while closing
    }
    // closing, quick (Ayoub: the empty ink must barely show): contents fade · the ink shrinks back into the pill under
    // the island with a decelerating curve (most of the way in the first frames) and, from half way, fades out · gone.
    // Total ≈ 250 ms (Motion.hiroba).
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "cv"; to: 0; duration: Motion.d(Motion.hiroba.fadeOut); easing.type: Easing.OutQuad }
        ScriptAction { script: root.freeze() }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "p"
                to: 0
                duration: Motion.d(Motion.hiroba.shrink)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.decel
            }
            SequentialAnimation {
                PauseAnimation { duration: Motion.d(Motion.hiroba.crossDelay) }
                ScriptAction { script: Panels.hirobaClosing = false }
                NumberAnimation { target: shape; property: "opacity"; to: 0; duration: Motion.d(Motion.hiroba.crossFade); easing.type: Easing.InQuad }
            }
        }
        ScriptAction { script: root.closed() }
    }
    Component.onCompleted: {
        freeze();
        run();
    }
    Component.onDestruction: Panels.hirobaClosing = false

    // the one-shot effects (speed lines, petals) start once the ink has arrived
    property bool arrived: false
    onPChanged: if (!arrived && p > 0.92 && want) arrived = true

    function clamp01(v: real): real {
        return Math.max(0, Math.min(1, v));
    }
    readonly property real g: Math.max(0, p)
    function mix(a: real, b: real): real {
        return a + (b - a) * g;
    }
    function rowIn(i: int): real {
        return clamp01((p - 0.45 - 0.1 * i) / 0.35) * cv;
    }

    Rectangle {
        id: shape
        x: (root.width - width) / 2
        y: 0                              // a pill of the island's size, right under the island (which stays)
        width: root.mix(root.fromW, root.width)
        height: root.mix(root.fromH, root.height)
        radius: root.fromR + (Theme.island.panelRadius - root.fromR) * Math.min(1, root.g)
        color: Theme.colors.island
        border.width: 1
        border.color: Theme.colors.islandBorder
        clip: true                        // a scissor (cheap): the rows never spill out while the ink grows

        // two soft glows (mock.css .hiroba::before), drawn as ROUNDED rectangles of the shape's own size
        Shape {
            anchors.fill: parent
            opacity: root.rowIn(0)
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: shape.width * 0.86; centerY: shape.height * 0.06; centerRadius: 520
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Theme.alpha(Theme.colors.accent2, 0.16) }
                    GradientStop { position: 0.7; color: Theme.alpha(Theme.colors.accent2, 0) }
                }
                PathRectangle { x: 0; y: 0; width: shape.width; height: shape.height; radius: shape.radius }
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: shape.width * 0.08; centerY: shape.height * 1.08; centerRadius: 600
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Theme.alpha(Theme.colors.accent, 0.13) }
                    GradientStop { position: 0.7; color: Theme.alpha(Theme.colors.accent, 0) }
                }
                PathRectangle { x: 0; y: 0; width: shape.width; height: shape.height; radius: shape.radius }
            }
        }
        // a rectangular clip inset by 0.3·radius lies inside the rounded corners: the watermark and the petals
        // never paint them square
        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: shape.radius * 0.3
            clip: true
            // the season's kanji, huge, in gold brush
            Kanji {
                visible: Settings.data.appearance.kanjiDecor && opacity > 0
                x: inner.width - width - 10
                y: inner.height - height + 60
                text: Kisetsu.ko.symbol || "季"
                brush: true
                size: 360
                font.weight: Font.Normal
                color: Theme.colors.accent2
                opacity: 0.045 * root.rowIn(1)
            }
            // petals of the season, once, when it opens
            Petals {
                anchors.fill: parent
                z: 20
                opacity: root.cv
                go: root.arrived && root.want
            }
        }
        // handle: a tap closes (the island's place)
        Rectangle {
            x: (shape.width - width) / 2
            y: 9
            width: 46
            height: 4
            radius: 2
            color: Theme.colors.islandTick
            opacity: root.rowIn(0)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -14
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.close()
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Cerrar 広場"
        }

        ColumnLayout {
            id: col
            x: 24 - shape.x
            y: 22 - shape.y
            width: root.width - 48
            spacing: 14
            visible: root.p > 0.4 && root.cv > 0

            // sections can be switched off in Ajustes → Barra e isla: they are then not created at all
            RowLayout {
                visible: root.sec.me || root.sec.clock || root.sec.neko
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.island.rowTop
                spacing: 14
                opacity: root.rowIn(0)
                transform: Translate { y: (1 - root.rowIn(0)) * 10 }
                Loader { active: root.sec.me; visible: active; Layout.preferredWidth: Theme.island.sideCard; Layout.fillHeight: true; sourceComponent: MeCard {} }
                Loader {
                    active: root.sec.clock
                    visible: active
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: Settings.data.hiroba.anime ? skyComp : plainClock
                }
                Loader {
                    // by URL, not by type: if Pipewire's API changes after an update only this card fails (docs/06 capa 3)
                    active: root.sec.neko
                    visible: active
                    Layout.preferredWidth: Theme.island.sideCard
                    Layout.fillHeight: true
                    source: "NekoCard.qml"
                    onStatusChanged: if (status === Loader.Error) Health.fail("広場 · ネコ", "no se pudo cargar la tarjeta")
                }
            }
            RowLayout {
                visible: root.sec.month || root.sec.season || root.sec.music
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.island.rowMid
                spacing: 14
                opacity: root.rowIn(1)
                transform: Translate { y: (1 - root.rowIn(1)) * 10 }
                Loader { id: month; active: root.sec.month; visible: active; Layout.preferredWidth: Theme.island.monthCard; Layout.fillHeight: true; sourceComponent: MonthCard {} }
                Loader { active: root.sec.season; visible: active; Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: SeasonCard {} }
                Loader {
                    active: root.sec.music
                    visible: active
                    Layout.preferredWidth: root.sec.season ? Theme.island.sideCard : -1
                    Layout.fillWidth: !root.sec.season
                    Layout.fillHeight: true
                    sourceComponent: MusicCard {}
                }
            }
            Loader {
                // the sampler lives inside: no section (or a drag that never opened 広場), no process
                active: root.sec.system && (root.want || root.cv > 0) && !root.dragging
                visible: root.sec.system
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.island.rowSys
                opacity: root.rowIn(2)
                transform: Translate { y: (1 - root.rowIn(2)) * 10 }
                sourceComponent: SystemRow {}
            }
        }
    }

    Component {
        id: skyComp
        SkyClock { burst: root.arrived }
    }
    Component {
        id: plainClock
        ClockBlock {}
    }

    // keys while open (the panel host has the keyboard): PgUp/PgDn months, Space play/pause (when music is shown)
    focus: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_PageUp && month.item) month.item.shift(-1);
        else if (e.key === Qt.Key_PageDown && month.item) month.item.shift(1);
        else if (e.key === Qt.Key_Space && root.sec.music) Media.playPause();
        else return;
        e.accepted = true;
    }
}
