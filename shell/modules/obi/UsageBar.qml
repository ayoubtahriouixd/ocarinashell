import QtQuick
import qs.config
import qs.components

// 墨 One live meter of the status cluster (CPU · RAM · GPU; Ayoub, fase 17: «barras con animación y el número
// encima»): the percentage on top, an ink stroke underneath that grows with a soft spring, and a peak tick that
// holds the highest recent value and sinks back slowly (a VU meter's peak hold). Hovering the cluster swaps the
// numbers for their kanji (脳 CPU · 記 RAM · 絵 GPU). Warning from 75 %, accent from 90 %. Nothing runs between
// Usage's samples: every animation starts on a new value and ends; Motion.enabled = false → it simply jumps.
Item {
    id: root
    property string label: ""
    property string kanji: ""
    property real value: 0                  // 0–1
    property bool showKanji: false
    readonly property real v: Math.max(0, Math.min(1, value))
    readonly property color tone: v >= 0.9 ? Theme.colors.accent : v >= 0.75 ? Theme.colors.warning : Theme.colors.text

    // peak hold: on every sample it is the new value or 85 % of the old peak, whichever is higher (≈ 15 s to settle
    // at the 2 s sampling rate), never below the value itself
    property real peak: 0
    onVChanged: peak = Math.max(v, peak * 0.85)

    implicitWidth: 18
    implicitHeight: 18
    Accessible.name: label + " " + Math.round(v * 100) + " %"

    // the number, or the kanji while hovering
    Item {
        width: parent.width
        height: 12
        OText {
            anchors.centerIn: parent
            text: Math.min(99, Math.round(root.v * 100))
            tabular: true
            size: 9.5
            font.weight: Font.DemiBold
            font.letterSpacing: -0.3
            color: root.v >= 0.9 ? Theme.colors.accent : Theme.colors.text
            opacity: root.showKanji ? 0 : 1
            Behavior on opacity { Anim { ms: Motion.fast } }
        }
        Kanji {
            anchors.centerIn: parent
            text: root.kanji
            size: 10
            color: Theme.colors.textMuted
            opacity: root.showKanji ? 1 : 0
            Behavior on opacity { Anim { ms: Motion.fast } }
        }
    }

    // the stroke: track, ink, peak
    Item {
        id: track
        y: 14
        width: parent.width
        height: 3
        clip: true                          // the spring's overshoot near 100 % stays inside the track
        Rectangle {
            anchors.fill: parent
            radius: 1.5
            color: Theme.alpha(Theme.colors.text, 0.14)
        }
        Rectangle {
            id: ink
            height: parent.height
            radius: 1.5
            width: parent.width
            color: root.tone
            // xScale through a Scale transform: the width never changes, so nothing relayouts while it grows
            transform: Scale {
                id: fill
                origin.x: 0
                xScale: root.v
                Behavior on xScale {
                    NumberAnimation {
                        duration: Motion.d(Motion.slow)
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }
            }
            Behavior on color { CAnim {} }
        }
        // the ink's wet tip: a brighter dot where the stroke ends
        Rectangle {
            x: Math.max(0, fill.xScale * track.width - width)
            width: 2
            height: parent.height
            radius: 1
            visible: root.v > 0.04
            color: Qt.lighter(root.tone, 1.35)
        }
        // peak hold
        Rectangle {
            x: Math.min(track.width - width, root.peak * track.width)
            width: 1.5
            height: parent.height
            visible: root.peak - root.v > 0.06
            color: Theme.alpha(Theme.colors.text, 0.55)
            Behavior on x { Anim { ms: Motion.emphasized } }
        }
    }
}
