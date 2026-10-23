pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.modules.shima
import qs.components
import qs.services

// 島 Shima — the living island (signature moment #2, docs/02-DISENO §5). One ink-black pill that morphs with a
// spring between: idle (eq · 21:38 · 水 14 · 菊) → hover (kanji date + micro-season) → music peek → OSD.
// Priority: OSD > hover > music peek > idle. Nothing animates at rest; the equaliser only runs while music plays,
// the island is visible and we are not in Shinobi.
Item {
    id: root

    property real dpr: 1.75
    readonly property alias hitArea: pill

    property bool hovered: false
    property bool osdOn: false
    property bool musicPeek: false
    property var peekNotif: null       // {app, summary, icon} shown for 2.5 s (DND or fullscreen)
    readonly property bool renaming: Panels.renameId >= 0
    readonly property string mode: renaming ? "rename" : osdOn ? "osd" : (hovered || Panels.islandHoverTest) ? "hover" : peekNotif ? "peek"
        : musicPeek && Media.active ? "music" : "idle"

    readonly property size target: {
        switch (mode) {
        case "rename": return Qt.size(Theme.island.osdWidth + 60, Theme.island.osdHeight);
        case "osd": return Osd.kind === "info"
            ? Qt.size(Math.min(Theme.island.maxWidth, osdLabel.implicitWidth + 80), Theme.island.osdHeight)
            : Qt.size(Theme.island.osdWidth, Theme.island.osdHeight);
        case "hover": return Qt.size(Math.max(idleRow.implicitWidth + 26, hoverCol.implicitWidth + 30), Theme.island.ticketHeight);
        case "peek": return Qt.size(Math.min(Theme.island.maxWidth, peekRow.implicitWidth + 32), Theme.island.musicHeight);
        case "music": return Qt.size(Math.min(Theme.island.musicMaxWidth, musicRow.implicitWidth + 30), Theme.island.musicHeight);
        default: return Qt.size(idleRow.implicitWidth + 26, Theme.island.height);
        }
    }

    width: pill.width
    height: pill.height
    // 保護 Hogo: the pill, its aura and its contents move together (a still pill around moving text looked off-centre)
    transform: Translate { x: Hogo.dx; y: Hogo.dy }

    // ── events ────────────────────────────────────────────────────────────────────────────────
    Connections {
        target: Osd
        function onSerialChanged() {
            if (!Settings.data.island.osd)
                return;
            root.osdOn = true;
            osdTimer.restart();
        }
    }
    Timer {
        id: osdTimer
        interval: Osd.kind === "info" ? 2500 : 1200
        onTriggered: root.osdOn = false
    }
    Connections {
        target: Notifs
        function onPeek(n) {
            if (!Settings.data.island.notifPeek)
                return;
            // 発表 presenting: the island is on the screen being copied → no content
            root.peekNotif = { app: n.appName || "Aplicación", summary: Displays.mirroring ? "Aviso nuevo" : n.summary };
            peekTimer2.restart();
        }
    }
    Timer {
        id: peekTimer2
        interval: 2500
        onTriggered: root.peekNotif = null
    }
    // recording time (seconds) only while recording
    property int recSeconds: 0
    Timer {
        interval: 1000
        repeat: true
        running: Recorder.recording && Settings.data.island.recording
        onTriggered: root.recSeconds = Math.round((Date.now() - Recorder.startedAt) / 1000)
        onRunningChanged: root.recSeconds = 0
    }
    Connections {
        target: Media
        function onTrackChanged() {
            if (!Settings.data.island.media || !Media.playing)
                return;
            root.musicPeek = true;
            peekTimer.restart();
        }
    }
    Timer {
        id: peekTimer
        interval: 3000
        onTriggered: root.musicPeek = false
    }

    // ── hover «wow» (one shot): the sweep crosses the ticket and four petals of the season jump off its right
    // end and fade. Nothing loops; without Motion (Shinobi, reduced motion) or with the effect off, nothing runs.
    readonly property bool wow: Motion.enabled && Settings.data.island.hoverFx && !Modes.shinobi
    onModeChanged: if (mode === "hover" && wow) { wowDelay.restart(); }
    Timer {
        id: wowDelay
        interval: Motion.d(Motion.fast)         // let the spring open the ticket first
        onTriggered: if (root.mode === "hover") { sweepAnim.restart(); petals.burst(); }
    }
    Item {
        id: petals
        z: 5
        x: pill.x + pill.width - 6
        y: pill.y + 8
        function burst(): void {
            for (let i = 0; i < 4; i++)
                rep.itemAt(i).fly.restart();
        }
        Repeater {
            id: rep
            model: 4
            delegate: Rectangle {
                id: pt
                required property int index
                property alias fly: flyAnim
                readonly property var path: [[22, -18, 140], [34, 6, 220], [16, 30, 90], [40, -4, 300]][index]
                width: 4.5
                height: 10
                radius: 2.25
                color: Theme.colors.accent2
                opacity: 0
                antialiasing: true
                ParallelAnimation {
                    id: flyAnim
                    XAnimator { target: pt; from: 0; to: pt.path[0]; duration: Motion.d(700); easing.type: Easing.OutCubic }
                    YAnimator { target: pt; from: 0; to: pt.path[1]; duration: Motion.d(700); easing.type: Easing.OutQuad }
                    RotationAnimator { target: pt; from: 0; to: pt.path[2]; duration: Motion.d(700) }
                    SequentialAnimation {
                        OpacityAnimator { target: pt; from: 0; to: 0.95; duration: Motion.d(90) }
                        PauseAnimation { duration: Motion.d(260 + pt.index * 40) }
                        OpacityAnimator { target: pt; from: 0.95; to: 0; duration: Motion.d(350) }
                    }
                }
            }
        }
    }

    // ── the pill ──────────────────────────────────────────────────────────────────────────────
    SoftShadow {
        target: pill
        offsetY: 6
        blur: 22
        color: Theme.alpha(Theme.colors.shadow, 0.5)
    }

    // 島 v2 (mockup 17): a 1 px aura from 紅 red to 金 gold around the ink, and a faint red glow. Static.
    readonly property bool aura: Settings.data.island.aura && !Modes.quiet
    SoftShadow {
        target: pill
        visible: root.aura
        offsetY: 0
        blur: 18
        color: Theme.alpha(Theme.colors.accent, 0.14)
    }
    Rectangle {
        visible: root.aura
        x: pill.x - 1
        y: pill.y - 1
        width: pill.width + 2
        height: pill.height + 2
        radius: pill.radius + 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(Theme.colors.accent, 0.75) }
            GradientStop { position: 0.35; color: Theme.alpha(Theme.colors.accent, 0.1) }
            GradientStop { position: 0.65; color: Theme.alpha(Theme.colors.accent2, 0.1) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.colors.accent2, 0.7) }
        }
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.target.width
        height: root.target.height
        radius: Math.min(height / 2, 22)
        color: Theme.colors.island
        border.width: root.aura ? 0 : 1
        border.color: Theme.colors.islandBorder
        clip: true

        Behavior on width {
            enabled: Motion.enabled
            SpringAnimation { spring: Motion.island.spring; damping: Motion.island.damping; epsilon: 0.3 }
        }
        Behavior on height {
            enabled: Motion.enabled
            SpringAnimation { spring: Motion.island.spring; damping: Motion.island.damping; epsilon: 0.3 }
        }

        // a light sweep crosses the ticket once when the hover begins (render thread, 450 ms)
        Rectangle {
            id: sweep
            visible: false
            y: -pill.height * 0.3
            width: 46
            height: pill.height * 1.6
            rotation: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Theme.alpha(Theme.colors.islandText, 0.22) }
                GradientStop { position: 1; color: "transparent" }
            }
            XAnimator {
                id: sweepAnim
                target: sweep
                from: -60
                to: pill.width + 20
                duration: Motion.d(Motion.emphasized)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
                onStarted: sweep.visible = true
                onFinished: sweep.visible = false
            }
        }

        // Hogo: the whole island drifts (root's Translate); the content only fades when static
        Item {
            id: content
            width: parent.width
            height: parent.height
            opacity: Hogo.dimmed && root.mode === "idle" ? 0.8 : 1
            Behavior on opacity { Anim { ms: Motion.ambient } }

            // ── idle: eq · time · day · kō ──────────────────────────────────────────────────
            RowLayout {
                id: idleRow
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                spacing: 9
                opacity: root.mode === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { ms: Motion.fast } }

                // 録 recording: red dot + elapsed time
                    Row {
                        visible: Recorder.recording && Settings.data.island.recording
                        spacing: 5
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.colors.accent
                        }
                        OText {
                            text: "録 " + Math.floor(root.recSeconds / 60) + ":" + String(root.recSeconds % 60).padStart(2, "0")
                            color: Theme.colors.islandText
                            size: 12.5
                            tabular: true
                        }
                    }
                    // 集中 focus: thin progress ring + minutes left (minute precision)
                    Row {
                        visible: Focus.active
                        spacing: 5
                        Canvas {
                            id: ring
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            property real p: Focus.progress
                            onPChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.lineWidth = 1.6;
                                ctx.strokeStyle = Theme.colors.islandTrack;
                                ctx.beginPath(); ctx.arc(7, 7, 5.6, 0, 2 * Math.PI); ctx.stroke();
                                ctx.strokeStyle = Theme.colors.accent;
                                ctx.lineCap = "round";
                                ctx.beginPath(); ctx.arc(7, 7, 5.6, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, p)); ctx.stroke();
                            }
                        }
                        OText {
                            text: Focus.remaining + "′"
                            color: Theme.colors.islandText
                            size: 12.5
                            tabular: true
                        }
                    }
                    // 船 Fune: Windows is booting to open an app (cold start, ~30 s); static, no spinner
                    Row {
                        visible: Fune.waking
                        spacing: 5
                        Kanji {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "船"
                            size: Theme.font.small
                            color: Theme.colors.asagi
                        }
                        OText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Windows despertando…"
                            color: Theme.colors.islandText
                            size: Theme.font.small
                        }
                    }
                // 忍 Shinobi: the island shrinks to seal · time · day; the seal is stamped once when the mode starts
                // (Motion.fade: the only motion allowed while the mode changes)
                Rectangle {
                    id: shinobiSeal
                    visible: Modes.shinobi
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: 6
                    color: Theme.colors.accent
                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Modo Shinobi activo"
                    Kanji {
                        anchors.centerIn: parent
                        text: "忍"
                        color: Theme.colors.accentInk
                        size: 13
                    }
                    onVisibleChanged: {
                        if (visible && Motion.modeFade && Motion.allowed)
                            stamp.restart();
                    }
                    ParallelAnimation {
                        id: stamp
                        NumberAnimation { target: shinobiSeal; property: "scale"; from: 1.8; to: 1; duration: Motion.fade(Motion.slow); easing.type: Easing.OutBack; easing.overshoot: Motion.sakugaOvershoot }
                        NumberAnimation { target: shinobiSeal; property: "opacity"; from: 0; to: 1; duration: Motion.fade(Motion.fast) }
                    }
                }
                // 鬼 Oni (mockup 08 .shima .hk.oni): black on 紅 with a gold rim; «覚醒» stamps it 1,6 → 1 with a
                // circular wave, once (Modes.awakened)
                Rectangle {
                    id: oniSeal
                    visible: Modes.oni
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: 6
                    color: Theme.colors.oni
                    border.width: 1.5
                    border.color: Theme.colors.oniGold
                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Modo Oni activo"
                    Kanji {
                        anchors.centerIn: parent
                        text: "鬼"
                        color: Theme.colors.oniInk
                        size: 13
                    }
                    Rectangle {
                        id: wave
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.colors.oni
                        opacity: 0
                    }
                    Connections {
                        target: Modes
                        function onAwakened() {
                            if (Motion.allowed)
                                awaken.restart();
                        }
                    }
                    // render-thread animators (docs/02-DISENO §4); Motion.fade: allowed while the mode changes
                    ParallelAnimation {
                        id: awaken
                        ScaleAnimator { target: oniSeal; from: 1.6; to: 1; duration: Motion.fade(Motion.slow); easing.type: Easing.OutBack; easing.overshoot: Motion.sakugaOvershoot }
                        OpacityAnimator { target: oniSeal; from: 0; to: 1; duration: Motion.fade(Motion.fast) }
                        // the pill clips: the wave grows only as far as the pill's height (a ring, not two arcs)
                        ScaleAnimator { target: wave; from: 1; to: 1.45; duration: Motion.fade(Motion.page); easing.type: Easing.OutCubic }
                        OpacityAnimator { target: wave; from: 0.9; to: 0; duration: Motion.fade(Motion.page); easing.type: Easing.OutCubic }
                    }
                }
                Kamon {
                    visible: !Modes.quiet && !Media.playing && !Recorder.recording && !Focus.active && !Fune.waking && Settings.data.appearance.kanjiDecor
                    implicitWidth: 18
                    implicitHeight: 18
                    Layout.leftMargin: -4
                }
                Equalizer {
                    id: eq
                    dpr: root.dpr
                    visible: Media.playing && !Modes.quiet
                    running: visible && root.mode === "idle" && root.visible
                }
                // 22:35 with the colon in 紅
                Text {
                    textFormat: Text.StyledText
                    text: Modes.quiet ? Time.hhmm : Time.hhmm.replace(":", "<font color=\"" + Theme.colors.accent + "\">:</font>")
                    color: Modes.shinobi ? Theme.colors.text : Theme.colors.islandText
                    font.family: Theme.font.ui
                    font.weight: Font.Bold
                    font.pointSize: 14.5 * 0.75 * Theme.font.scale
                    font.features: { "tnum": 1 }
                }
                // 鬼 Oni: 「脳 78° 絵 71° 電 34 W」 (Sensors, every 2 s while the mode is on)
                Repeater {
                    // a fixed model: only the numbers change every 2 s, the three delegates stay
                    model: Modes.oni ? [{ k: "脳", u: "°", a: "CPU" }, { k: "絵", u: "°", a: "GPU" }, { k: "電", u: " W", a: "Potencia" }] : []
                    delegate: Row {
                        id: stat
                        required property var modelData
                        readonly property real v: modelData.k === "脳" ? Sensors.cpuTemp : modelData.k === "絵" ? Sensors.gpuTemp : Sensors.watts
                        visible: !isNaN(v)
                        spacing: 3
                        Accessible.role: Accessible.StaticText
                        Accessible.name: modelData.a + " " + Math.round(v) + modelData.u
                        Kanji {
                            anchors.baseline: statV.baseline
                            text: stat.modelData.k
                            color: Theme.colors.islandMuted
                            font.family: Theme.font.display
                            font.weight: Font.Medium
                            size: 12.5
                        }
                        OText {
                            id: statV
                            text: Math.round(stat.v) + stat.modelData.u
                            color: Theme.colors.islandText
                            size: 13
                            font.weight: Font.DemiBold
                            tabular: true
                        }
                    }
                }
                // the day as a seal: 木 15 in a thin red frame
                Rectangle {
                    visible: !Modes.oni
                    implicitWidth: dayRow.implicitWidth + (Modes.shinobi ? 0 : 10)
                    implicitHeight: 18
                    radius: 5
                    color: "transparent"
                    border.width: Modes.shinobi ? 0 : 1
                    border.color: Theme.alpha(Theme.colors.accent, 0.7)
                    Row {
                        id: dayRow
                        anchors.centerIn: parent
                        spacing: 3
                        // 忍 Shinobi (mockup 06 .shima .day): «水 14» as plain text, gothic 13/500 on one baseline
                        Kanji {
                            id: dayKanji
                            anchors.verticalCenter: Modes.shinobi ? undefined : parent.verticalCenter
                            text: Glossary.weekday(Time.weekday).kanji
                            color: Modes.shinobi ? Theme.colors.textMuted : Theme.colors.islandText
                            font.family: Modes.shinobi ? Theme.font.jp : Theme.font.display
                            font.weight: Modes.shinobi ? Font.Medium : Font.Bold
                            size: Modes.shinobi ? 13 : 11.5
                        }
                        OText {
                            // y instead of anchors: swapping verticalCenter ↔ baseline anchors warns mid-switch
                            y: Modes.shinobi ? dayKanji.y + dayKanji.baselineOffset - baselineOffset
                                             : (parent.height - height) / 2
                            text: Time.dayOfMonth
                            color: Modes.shinobi ? Theme.colors.textMuted : Theme.colors.islandText
                            size: Modes.shinobi ? 13 : 11
                            font.weight: Modes.shinobi ? Font.Medium : Font.DemiBold
                            tabular: true
                        }
                    }
                }
                Kanji {
                    visible: !Modes.quiet && Settings.data.bar.showKisetsu && Kisetsu.ko.symbol !== ""
                    text: Kisetsu.ko.symbol
                    brush: true
                    font.weight: Font.Normal
                    color: Theme.colors.accent2
                    size: 15
                    transform: Translate { y: -1 }       // Yuji Syuku sits low in its line box
                }
            }

            // ── hover «ticket» (mockup 17): crest · [date ribbon / 菊花開 · meaning · days] · weather ──────
            RowLayout {
                id: hoverCol
                anchors.centerIn: parent
                spacing: 12
                opacity: root.mode === "hover" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { ms: Motion.fast } }

                Kamon {
                    implicitWidth: 38
                    implicitHeight: 38
                }
                ColumnLayout {
                    spacing: 6
                    // the date on a slanted red ribbon (an anime title tag)
                    Item {
                        implicitWidth: ribText.implicitWidth + 18
                        implicitHeight: 18
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.colors.accent
                            antialiasing: true
                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.21, 0, 3.8, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        }
                        Kanji {
                            id: ribText
                            anchors.centerIn: parent
                            text: Time.kanjiDate
                            color: Theme.colors.accentInk
                            size: 11
                            font.letterSpacing: 11 * 0.12
                        }
                    }
                    Row {
                        spacing: 7
                        Kanji {
                            anchors.baseline: koEs.baseline
                            text: Kisetsu.ko.kanji ?? ""
                            brush: true
                            font.weight: Font.Normal
                            color: Theme.colors.accent2
                            size: 15
                        }
                        OText {
                            id: koEs
                            text: (Kisetsu.ko.es ?? "").toLowerCase() + " · quedan " + Kisetsu.koDaysLeft
                                + (Kisetsu.koDaysLeft === 1 ? " día" : " días")
                            color: Theme.colors.islandMuted
                            size: 11.5
                        }
                    }
                }
                Rectangle {
                    visible: Weather.available
                    implicitWidth: 1
                    implicitHeight: 30
                    color: Theme.colors.islandSep
                }
                Row {
                    visible: Weather.available
                    spacing: 6
                    Kanji {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.info(Weather.code).kanji ?? ""
                        color: Theme.colors.islandText
                        size: 20
                    }
                    OText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Weather.temperature) + "°"
                        color: Theme.colors.islandText
                        size: 18
                        font.weight: Font.Light
                        tabular: true
                    }
                }
            }

            // ── music peek: cover · title / artist · eq ─────────────────────────────────────
            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: 10
                opacity: root.mode === "music" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { ms: Motion.fast } }

                // round cover: square image + a ring in the island colour over the corners (no clipping shader)
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Theme.colors.surface2
                    }
                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        sourceSize: Qt.size(28 * root.dpr, 28 * root.dpr)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28 + 2 * 8
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 8
                        border.color: Theme.colors.island
                    }
                }
                ColumnLayout {
                    spacing: 1
                    Layout.maximumWidth: 250
                    OText {
                        Layout.maximumWidth: 250
                        text: Media.title
                        color: Theme.colors.islandText
                        size: 12.5
                        font.weight: Font.DemiBold
                    }
                    OText {
                        Layout.maximumWidth: 250
                        text: Media.artist
                        color: Theme.colors.islandMuted
                        size: 11
                    }
                }
                Equalizer {
                    dpr: root.dpr
                    running: root.mode === "music" && Media.playing && !Modes.shinobi
                }
            }

            // ── peek: an incoming notification while Do-not-disturb (or fullscreen) ─────────────
            RowLayout {
                id: peekRow
                anchors.centerIn: parent
                spacing: 8
                opacity: root.mode === "peek" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { ms: Motion.fast } }
                Kanji { text: "文"; size: 13; color: Theme.colors.accent }
                OText {
                    text: root.peekNotif ? root.peekNotif.app + " · " + root.peekNotif.summary : ""
                    textFormat: Text.PlainText
                    color: Theme.colors.islandText
                    size: 12.5
                    Layout.maximumWidth: Theme.island.maxWidth - 60
                }
            }

            // ── rename: 名 · field (↵ applies, empty = back to the numeral, Esc cancels) ─────────
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                opacity: root.mode === "rename" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { ms: Motion.fast } }
                Kanji { text: "名"; size: 16; color: Theme.colors.accent }
                TextInput {
                    id: renameField
                    Layout.fillWidth: true
                    color: Theme.colors.islandText
                    selectionColor: Theme.alpha(Theme.colors.accent, 0.45)
                    font.family: Theme.font.ui
                    font.pointSize: 13.5 * 0.75 * Theme.font.scale
                    maximumLength: 24
                    onTextChanged: Panels.renameDraft = text
                    clip: true
                    cursorDelegate: Rectangle { width: 2; color: Theme.colors.accent }
                    Keys.onReturnPressed: Panels.endRename(text)
                    Keys.onEnterPressed: Panels.endRename(text)
                    Keys.onEscapePressed: Panels.endRename(null)
                    OText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: renameField.text === ""
                        text: "Nombre del espacio"
                        size: 13.5
                        color: Theme.colors.islandMuted
                    }
                }
                OText { text: "↵ · Esc"; size: 12; color: Theme.colors.islandMuted }
            }
            // clicking or moving to another window/workspace abandons the edit (the keyboard is not held hostage)
            Connections {
                target: Niri
                enabled: root.renaming
                // the exclusive keyboard itself makes niri report "no focused window" (-1): only a different real
                // window means the user clicked elsewhere
                function onFocusedWindowIdChanged() {
                    if (Niri.focusedWindowId >= 0 && Niri.focusedWindowId !== Panels.renameWindow)
                        Panels.endRename(null);
                }
                function onWorkspacesChanged() {
                    if ((Niri.workspaces.find(w => w.is_focused)?.id ?? -1) !== Panels.renameFrom)
                        Panels.endRename(null);
                }
            }
            Connections {
                target: Panels
                function onRenameIdChanged() {
                    if (Panels.renameId < 0)
                        return;
                    renameField.text = Panels.renameName;
                    renameField.selectAll();
                    renameField.forceActiveFocus();
                }
            }
            // a forgotten edit does not keep the keyboard forever
            Timer {
                running: root.renaming
                interval: 60000
                onTriggered: Panels.endRename(null)
            }

            // ── OSD: icon · label / bar · value ─────────────────────────────────────────────
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                opacity: root.mode === "osd" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { ms: Motion.fast } }

                OIcon {
                    icon: Osd.icon
                    fill: true
                    size: 20
                    color: Theme.colors.islandText
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    OText {
                        id: osdLabel
                        Layout.fillWidth: true
                        text: Osd.label
                        color: Theme.colors.islandMuted
                        size: 11.5
                    }
                    Rectangle {
                        visible: Osd.kind !== "info" && Osd.kind !== "profile"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Theme.colors.islandTrack
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Osd.value))
                            height: parent.height
                            radius: 2
                            color: Theme.colors.accent
                            Behavior on width { Anim { ms: Motion.fast } }
                        }
                    }
                }
                OText {
                    visible: Osd.kind !== "info" && Osd.kind !== "profile" && Osd.kind !== "mic"
                    text: Math.round(Osd.value * 100)
                    color: Theme.colors.islandText
                    size: 13
                    font.weight: Font.DemiBold
                    tabular: true
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 26
                }
            }
        }

        HoverHandler {
            onHoveredChanged: {
                root.hovered = hovered && Settings.data.island.hover;
                Hogo.activity();
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.mode !== "rename"          // the name field takes the clicks then
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.toggle("hiroba", "")
        }
        WheelStep {
            enabled: Settings.data.island.wheelVolume
            onStep: dir => dir > 0 ? Audio.increment("5") : Audio.decrement("5")
        }
        // touch: pull down = 広場 Hiroba; swipe sideways with music = next / previous track
        PullDown {
            panel: "hiroba"
            distance: 560                     // 広場 is ~646 tall: the ink follows the finger, not ahead of it
            onSwipeLeft: if (Media.active && Settings.data.island.swipeTracks) Media.next()
            onSwipeRight: if (Media.active && Settings.data.island.swipeTracks) Media.previous()
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Isla: " + Time.hhmm + ", " + Time.spanishDate
    }
}
