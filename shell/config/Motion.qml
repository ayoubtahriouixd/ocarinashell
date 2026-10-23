pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Motion tokens (docs/02-DISENO §4). One switch turns everything still: Motion.enabled = false in Shinobi, Oni or
// reduced motion. d(ms) = 0 then, and every animation jumps to its final state without breaking anything.
Singleton {
    id: root

    // appearance.animSpeed is a SPEED (Settei: 0 = no animations, 0.5–2×): durations are divided by it (D-046)
    readonly property real speed: Number(Settings.data.appearance.animSpeed) || 0
    readonly property bool allowed: !Settings.data.appearance.reducedMotion && speed > 0.01
    // held: written by Modes (忍 Shinobi, 鬼 Oni) — config never imports services, services write here
    property bool held: false
    readonly property bool enabled: allowed && !held
    // modeFade: Modes raises it for ~1 s while entering/leaving a mode: the theme fade to black and the 忍 stamp
    // are the only motion allowed then (never with reduced motion or speed 0)
    property bool modeFade: false
    readonly property real scale: 1 / Math.max(0.5, Math.min(2, speed))

    readonly property int micro: 90
    readonly property int fast: 150
    readonly property int base: 220
    readonly property int slow: 320
    readonly property int emphasized: 450
    readonly property int page: 600
    readonly property int farewell: 400      // the farewell ground fading in (= Plymouth's shutdown splash entrance)
    readonly property int ambient: 1000      // slow fades nobody should notice (Hogo dimming)

    function d(ms: real): int {
        return enabled ? Math.round(ms * scale) : 0;
    }
    // theme colour fades: also while a mode changes (see modeFade)
    function fade(ms: real): int {
        return enabled || (modeFade && allowed) ? Math.round(ms * scale) : 0;
    }

    // BezierSpline control points (Easing.BezierSpline)
    readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
    readonly property list<real> decel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> accel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property real sakugaOvershoot: 1.3

    // Springs (SpringAnimation): island morph and the workspace hanko
    readonly property QtObject island: QtObject {
        readonly property real spring: 4.2
        readonly property real damping: 0.32
    }
    readonly property QtObject hanko: QtObject {
        readonly property real spring: 5
        readonly property real damping: 0.38
    }
    // 広場 Hiroba: quick in, quick out (Ayoub: the empty ink must barely show) — ms, scaled by d()
    readonly property QtObject hiroba: QtObject {
        readonly property int open: 240
        readonly property int fadeOut: 60
        readonly property int shrink: 190
        readonly property int crossDelay: 80
        readonly property int crossFade: 110
        readonly property int safety: 1500        // panel host's net if `closed` never comes
    }
    // 器 the ocarina's app drawer — ms, scaled by d(): the glass springs out (OutBack), the tiles arrive in a cascade
    readonly property QtObject drawer: QtObject {
        readonly property int open: 380           // the spring of the glass (slow + a little room for the overshoot)
        readonly property real overshoot: 1.15
        readonly property int stagger: 14         // between two tiles of the opening cascade
        readonly property int cascadeDepth: 24    // tiles further down arrive together with the 24th
        readonly property int cascadeEnd: 900     // > 24 × 14 + slow: then the cascade is dropped for good
    }
}
