pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Real equaliser from PipeWire peaks of the default sink (mockup: 4 bars, 2.5 px, max 13 px, accent).
// The peak monitor only exists while `live`: zero cost when hidden, paused, with motion reduced (Shinobi, Oni,
// reduced motion), on battery, locked, with the screens off by idle, or under a full-screen window on its output.
// Not live → the bars rest in a fixed shape (never disappear).
Item {
    id: root
    property bool running: false
    property color color: Theme.colors.accent
    implicitWidth: 4 * 2.5 + 3 * 2
    implicitHeight: 13

    // niri has no «fullscreen» flag in its IPC (26.04): the focused window covers its whole output (same rule as
    // 滑 Nameraka). Top-layer surfaces (the bar, PanelHost) are hidden under it. Only the focused window's layout is
    // tracked, so a full-screen window on an output that lost focus does not count (the bars just keep moving).
    readonly property string output: QsWindow.window?.screen?.name ?? ""
    readonly property bool covered: {
        if (!running)
            return false;
        const w = Niri.focusedWindow;
        const lay = Niri.focusedLayout ?? w?.layout;
        if (!w || !lay?.window_size)
            return false;
        const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
        const out = ws?.output ?? "";
        if (out === "" || (output !== "" && out !== output))
            return false;
        const l = Niri.outputs[out]?.logical;
        const pos = lay.tile_pos_in_workspace_view;
        const atOrigin = !pos || (Math.abs(pos[0]) < 1 && Math.abs(pos[1]) < 1);
        return !!l && atOrigin && Math.abs(lay.window_size[0] - l.width) <= 1 && Math.abs(lay.window_size[1] - l.height) <= 1;
    }
    readonly property bool live: running && Motion.enabled && !Lock.active && !Idle.offIdle && !Power.onBattery && !covered

    // sampled at ~15 Hz (PipeWire updates far faster, and every change repaints the bar surface the island lives in).
    // Fast attack, eased release: a louder peak shows at once, a quieter one blends with the last sample, so 15 Hz
    // does not look choppy — without any animation (that would repaint at the panel's refresh rate).
    property real l: 0
    property real r: 0
    property real dpr: 1.75
    Timer {
        interval: 66
        repeat: true
        running: root.live && monitor.item !== null
        onTriggered: {
            const p = monitor.item.peaks;
            const nl = p.length > 0 ? p[0] : 0;
            const nr = p.length > 1 ? p[1] : nl;
            root.l = Math.max(nl, root.l * 0.5 + nl * 0.5);
            root.r = Math.max(nr, root.r * 0.5 + nr * 0.5);
        }
    }
    onLiveChanged: if (!live) { l = 0; r = 0; }
    function px(h: real): real {          // snap to physical pixels: unchanged bars do not notify
        return Math.round(h * dpr) / dpr;
    }
    // a different curve per bar spreads the (rather constant) peaks of mastered music into a lively shape
    readonly property list<real> levels: live
        ? [Math.pow(l, 0.9), Math.pow(Math.max(l, r), 0.6), Math.pow(r, 0.8), Math.pow((l + r) / 2, 1.0)]
        : [0.45, 0.9, 0.6, 0.8]

    LazyLoader {
        id: monitor
        active: root.live && Pipewire.defaultAudioSink !== null
        PwNodePeakMonitor {
            node: Pipewire.defaultAudioSink
            enabled: true
        }
    }

    Row {
        anchors.bottom: parent.bottom
        height: 13
        spacing: 2
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: 2.5
                height: root.px(Math.max(3, 13 * Math.min(1, root.levels[index])))
                anchors.bottom: parent.bottom
                radius: 2
                color: root.color
            }
        }
    }
}
