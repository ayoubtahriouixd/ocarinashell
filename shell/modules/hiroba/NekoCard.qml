pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · ネコ vibe cat (Ayoub, fase 15: replaces «sol y luna»; a cyberpunk «vibing cat» in neon). The grey neon is
// always grey; the red one follows the theme's accent (Ayoub, fase 17: «si pongo verde que sea verde – gris»): the
// layers come as base + tint (tools/neko_gen.py) and shaders/nekotint.frag puts the accent back in. A neon night scene in layers (assets/neko/*.png, tools/neko_gen.py) the size of the card:
// - music playing: the cat nods on the REAL beats (onsets in PipeWire's peaks of the default sink; a steady
//   ~60 bpm if the peaks say nothing), the neon equaliser follows the audio and the visor turns into an LED one;
// - nothing playing: the cat stands still and the bars rest;
// - the ネコ sign flickers now and then; a click plays/pauses. Only exists while 広場 is open; with Motion off
//   (reduced motion, Shinobi) everything stands still and the peak monitor is not even created.
HbCard {
    id: root

    readonly property bool moving: Motion.enabled
    readonly property bool vibing: Media.playing && moving
    readonly property real k: width / 284          // the layers are drawn for 284×150
    property real l: 0
    property real r: 0
    property real fast: 0
    property real slow: 0
    property real lastBeat: 0
    property int beats: 0

    // the accent as neon: the theme's hue at full brightness (Matcha's dark olive would glow dim); greys stay as they are
    readonly property color accent: Theme.colors.accent
    readonly property color neon: accent.hsvSaturation < 0.12 ? accent
        : Qt.hsva(accent.hsvHue, accent.hsvSaturation, Math.max(accent.hsvValue, 0.95), 1)

    component Layer: Item {
        id: layer
        required property string part
        readonly property bool tinted: part !== "fx"          // fx (scanlines, vignette) has no neon
        width: root.width
        height: root.height
        Image {
            anchors.fill: parent
            visible: !layer.tinted
            source: layer.tinted ? "" : Paths.asset("neko/" + layer.part + ".png")
            smooth: true
            mipmap: true
        }
        Image {
            id: baseTex
            anchors.fill: parent
            visible: false
            source: layer.tinted ? Paths.asset("neko/" + layer.part + "-base.png") : ""
            smooth: true
            mipmap: true
        }
        Image {
            id: tintTex
            anchors.fill: parent
            visible: false
            source: layer.tinted ? Paths.asset("neko/" + layer.part + "-tint.png") : ""
            smooth: true
            mipmap: true
        }
        ShaderEffect {
            anchors.fill: parent
            visible: layer.tinted
            property var base: baseTex
            property var tint: tintTex
            property color accent: root.neon
            fragmentShader: Qt.resolvedUrl("../../shaders/nekotint.frag.qsb")
        }
    }

    Layer { part: "bg" }
    Layer {
        id: sign
        part: "sign"
    }

    // ── neon equaliser on the horizon, with its reflection on the floor (the 30 Hz sampling is its smoothing) ──
    Row {
        x: 50 * root.k
        y: 112 * root.k
        spacing: 3 * root.k
        Repeater {
            model: 9
            delegate: Item {
                id: bar
                required property int index
                // each bar answers a different curve of the peaks (one spectrum-like shape from two numbers)
                // relative to the track's own loudness (the slow average), so quiet music still dances
                readonly property real level: root.vibing
                    ? Math.min(1, Math.pow((index % 2 ? root.l : root.r) / Math.max(0.12, root.slow * 1.35),
                                           1.6 + 0.5 * (index % 3))
                               * (0.55 + 0.45 * Math.abs(Math.sin(root.beats * 1.7 + index * 1.3))))
                    : 0.12 + 0.06 * ((index * 7) % 3)
                width: 7 * root.k
                height: 1                           // a positioner skips zero-height items
                Rectangle {
                    width: parent.width
                    height: Math.max(2, 46 * root.k * bar.level)
                    y: -height
                    radius: 1.5
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.neon }
                        GradientStop { position: 1; color: "#8e8e96" }
                    }
                }
                Rectangle {                         // reflection
                    width: parent.width
                    height: Math.max(1, 16 * root.k * bar.level)
                    y: 1
                    radius: 1.5
                    opacity: 0.28
                    color: root.neon
                }
            }
        }
    }

    Layer { part: "body" }
    // the head nods around the neck (196,106): a wrapper centred there, its layer back at the card's origin
    Item {
        id: head
        width: 2 * 196 * root.k
        height: 2 * 106 * root.k
        Layer { part: "head" }
        // the visor (Ayoub: no text): with music it becomes an LED equaliser, bars mirrored from its centre line
        // following the real peaks; silent, it stays dark
        Row {
            id: visorEq
            x: (163 + 33) * root.k - width / 2
            y: 70 * root.k
            spacing: 2.3 * root.k
            opacity: root.vibing ? 1 : 0
            Behavior on opacity { enabled: root.moving; Anim { ms: Motion.base } }
            Repeater {
                model: 13
                delegate: Item {
                    id: led
                    required property int index
                    // a spectrum-like hump (the middle taller) shaped by the peaks and the beat counter
                    readonly property real hump: 1 - Math.pow(Math.abs(index - 6) / 7, 1.6)
                    readonly property real level: root.vibing
                        ? Math.min(1, hump * Math.pow((index % 2 ? root.l : root.r) / Math.max(0.12, root.slow * 1.3), 1.4)
                                   * (0.5 + 0.5 * Math.abs(Math.sin(root.beats * 2.3 + index * 0.9))))
                        : 0
                    width: 2.2 * root.k
                    height: 1                       // a positioner skips zero-height items
                    Rectangle {
                        width: parent.width
                        height: Math.max(1.2, 14 * root.k * led.level)
                        y: -height / 2
                        radius: width / 2
                        color: led.index === 6 ? "#ffffff" : led.index % 3 === 0 ? Qt.lighter(root.neon, 1.12) : "#d6dae0"
                    }
                }
            }
        }
    }
    Layer { part: "fx" }

    // ── beats ──
    // nod: down and back up with a small tilt that alternates side (the meme's groove)
    ParallelAnimation {
        id: nod
        SequentialAnimation {
            YAnimator { target: head; from: 0; to: 4.5 * root.k; duration: 90; easing.type: Easing.OutQuad }
            YAnimator { target: head; from: 4.5 * root.k; to: 0; duration: 250; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            RotationAnimator { id: tiltIn; target: head; from: 0; to: 4; duration: 90; easing.type: Easing.OutQuad }
            RotationAnimator { id: tiltOut; target: head; from: 4; to: 0; duration: 250; easing.type: Easing.InOutSine }
        }
    }
    function beat(): void {
        lastBeat = Date.now();
        beats++;
        const t = beats % 2 ? 4 : -4;
        tiltIn.to = t;
        tiltOut.from = t;
        nod.restart();
    }
    LazyLoader {
        id: monitor
        active: root.vibing && Pipewire.defaultAudioSink !== null
        PwNodePeakMonitor {
            node: Pipewire.defaultAudioSink
            enabled: true
        }
    }
    // onset detection at ~30 Hz: a fast energy average jumping over a slow one is a beat (≥ 280 ms apart)
    Timer {
        interval: 33
        repeat: true
        running: root.vibing
        onTriggered: {
            const p = monitor.item?.peaks ?? [];
            root.l = p.length > 0 ? p[0] : 0;
            root.r = p.length > 1 ? p[1] : root.l;
            const e = Math.max(root.l, root.r);
            root.fast = root.fast * 0.5 + e * 0.5;
            root.slow = root.slow * 0.94 + e * 0.06;
            const now = Date.now();
            if (now - root.lastBeat > 280 && root.fast > 0.08 && root.fast > root.slow * 1.22 + 0.015)
                root.beat();
            else if (now - root.lastBeat > 1000)
                root.beat();              // the peaks say nothing (no monitor, a flat track): keep the groove
        }
        onRunningChanged: if (!running) { root.l = 0; root.r = 0; root.fast = 0; root.slow = 0; }
    }

    // ── the sign flickers every few seconds ──
    SequentialAnimation {
        running: root.moving
        loops: Animation.Infinite
        PauseAnimation { duration: 3200 }
        OpacityAnimator { target: sign; from: 1; to: 0.25; duration: 40 }
        OpacityAnimator { target: sign; from: 0.25; to: 1; duration: 60 }
        PauseAnimation { duration: 90 }
        OpacityAnimator { target: sign; from: 1; to: 0.4; duration: 40 }
        OpacityAnimator { target: sign; from: 0.4; to: 1; duration: 120 }
        PauseAnimation { duration: 5200 }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Media.playPause()
    }
    Accessible.role: Accessible.Button
    Accessible.name: Media.playing ? "Gato vibing: bailando. Pulsa para pausar la música" : "Gato vibing: pulsa para reproducir"
}
