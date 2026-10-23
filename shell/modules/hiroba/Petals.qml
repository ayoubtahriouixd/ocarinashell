pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Petals of the season falling across 広場 ONCE when it opens (2,4 s, render-thread animators), then gone: nothing
// keeps the panel repainting afterwards. Colour from the season's crest (菊 gold, 桜 pink, 梅 white, 夏 asagi).
Item {
    id: root
    property bool go: false
    readonly property bool on: Settings.data.hiroba.anime && Settings.data.hiroba.petals && Motion.enabled && !Modes.shinobi
    // the crest's colour for this month (same rule as Kamon) — no hidden crest instantiated just to read it
    readonly property color petal: {
        const m = Time.month;
        return m >= 2 && m <= 4 ? Theme.colors.sakura : m >= 5 && m <= 7 ? Theme.colors.asagi
            : m >= 8 && m <= 10 ? Theme.colors.accent2 : Theme.colors.islandText;
    }
    function fall(): void {
        if (!on)
            return;
        for (let i = 0; i < rep.count; i++)
            rep.itemAt(i).drop.restart();
    }
    onGoChanged: {
        if (go)
            fall();
        else
            for (let i = 0; i < rep.count; i++) {
                rep.itemAt(i).drop.stop();
                rep.itemAt(i).opacity = 0;
            }
    }
    Repeater {
        id: rep
        model: 12
        delegate: Rectangle {
            id: pt
            required property int index
            property alias drop: dropAnim
            readonly property real sx: ((index * 89 + 23) % 100) / 100 * root.width
            readonly property real dur: 1700 + (index * 137) % 900
            width: 5 + (index % 3)
            height: 11 + (index % 4) * 1.5
            radius: width / 2
            color: root.petal
            opacity: 0
            antialiasing: true
            ParallelAnimation {
                id: dropAnim
                YAnimator { target: pt; from: -20 - (pt.index % 4) * 30; to: root.height * (0.55 + (pt.index % 5) * 0.09); duration: Motion.d(pt.dur); easing.type: Easing.InOutSine }
                XAnimator { target: pt; from: pt.sx; to: pt.sx + 40 + (pt.index % 3) * 26; duration: Motion.d(pt.dur); easing.type: Easing.InOutSine }
                RotationAnimator { target: pt; from: pt.index * 30; to: pt.index * 30 + 260; duration: Motion.d(pt.dur) }
                SequentialAnimation {
                    PauseAnimation { duration: Motion.d((pt.index % 6) * 70) }
                    OpacityAnimator { target: pt; from: 0; to: 0.75; duration: Motion.d(200) }
                    PauseAnimation { duration: Motion.d(pt.dur * 0.5) }
                    OpacityAnimator { target: pt; from: 0.75; to: 0; duration: Motion.d(pt.dur * 0.35) }
                }
            }
        }
    }
}
