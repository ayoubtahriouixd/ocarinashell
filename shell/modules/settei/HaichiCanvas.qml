pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.config
import qs.components
import qs.services

// 配置 canvas (mock.css .canvas/.scr): the screens at logical scale on a dotted surface0 board. Drag a screen and
// let go: it snaps to the nearest edge of another one (the guide is a dashed accent line), then Displays applies
// the new position as a 15 s trial. Numbered with the formal numerals 壱 弐 参; the primary wears the 主 hanko.
// Keyboard: Tab goes from screen to screen (focus selects it), the arrows move the focused one 10 logical px (Shift: 1)
// and the position is applied like a drop 700 ms after the last key (one trial per burst, no magnet).
Rectangle {
    id: root
    property string selected: ""
    signal picked(string name)

    // the screens are recreated whenever Displays re-reads the outputs: the one that had the keyboard keeps it
    property string keyFocus: ""
    readonly property Item focused: Window.activeFocusItem
    onFocusedChanged: {
        // a destroyed card leaves the focus on a scope (not a Tab stop): only a real move elsewhere forgets it
        if (focused && focused.activeFocusOnTab && focused.parent !== root)
            keyFocus = "";
    }

    implicitHeight: 210
    radius: 12
    color: Theme.colors.surface0
    border.width: 1
    border.color: Theme.colors.outline
    clip: true

    // dots every 14 px (radial dots at 10 % of the text colour): painted once per size or theme change
    Canvas {
        id: dots
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        property color dot: Theme.alpha(Theme.colors.text, 0.12)
        onDotChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = dot;
            for (let y = 7; y < height; y += 14)
                for (let x = 7; x < width; x += 14) {
                    ctx.beginPath();
                    ctx.arc(x, y, 1.2, 0, 2 * Math.PI);
                    ctx.fill();
                }
        }
    }

    // logical → canvas transform: fit every enabled screen (disabled ones are drawn after them, dimmed)
    readonly property var shown: {
        const en = Displays.list.filter(o => o.enabled);
        const out = en.map(o => ({ o: o, x: o.x, y: o.y, w: o.lw, h: o.lh }));
        let x = en.length ? Math.max(...en.map(o => o.x + o.lw)) + 200 : 0;
        for (const o of Displays.list.filter(o => !o.enabled)) {
            const m = o.modes.find(m => m.pref) ?? o.modes[0] ?? { w: 1920, h: 1080 };
            out.push({ o: o, x: x, y: 0, w: m.w / 1.5, h: m.h / 1.5 });
            x += m.w / 1.5 + 200;
        }
        return out;
    }
    readonly property var box: {
        if (shown.length === 0)
            return { x: 0, y: 0, w: 1, h: 1 };
        const x0 = Math.min(...shown.map(s => s.x)), y0 = Math.min(...shown.map(s => s.y));
        const x1 = Math.max(...shown.map(s => s.x + s.w)), y1 = Math.max(...shown.map(s => s.y + s.h));
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
    }
    readonly property real k: Math.min((width - 76) / box.w, (height - 66) / box.h)
    readonly property real ox: (width - box.w * k) / 2
    readonly property real oy: (height - box.h * k) / 2
    function cx(lx: real): real { return ox + (lx - box.x) * k; }
    function cy(ly: real): real { return oy + (ly - box.y) * k; }

    // snap guide while dragging
    property real snapX: -1
    Rectangle {
        visible: root.snapX >= 0
        x: root.snapX - 0.75
        y: 20
        width: 1.5
        height: root.height - 40
        color: "transparent"
        Column {
            spacing: 4
            Repeater {
                model: Math.ceil((root.height - 40) / 8)
                delegate: Rectangle { width: 1.5; height: 4; color: Theme.colors.accent; opacity: 0.85 }
            }
        }
    }

    Repeater {
        model: root.shown
        delegate: Item {
            id: scr
            required property var modelData
            required property int index
            readonly property var o: modelData.o
            readonly property bool sel: root.selected === o.name
            // only an enabled screen among several can move (with one there is nothing to arrange)
            readonly property bool movable: o.enabled && Displays.list.filter(x => x.enabled).length > 1
            // keyboard offset not applied yet (logical px)
            property real kx: 0
            property real ky: 0
            // 1.5 px inset: neighbours never touch (and a halo never sits on the next card)
            x: root.cx(modelData.x + kx) + 1.5 + (drag.active ? drag.translation.x : 0)
            y: root.cy(modelData.y + ky) + 1.5 + (drag.active ? drag.translation.y : 0)
            width: modelData.w * root.k - 3
            height: modelData.h * root.k - 3
            z: drag.active ? 10 : sel ? 2 : 1
            opacity: o.enabled ? 1 : 0.45

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 13
                visible: scr.sel
                color: Theme.colors.accentSoft
            }
            Rectangle {
                id: card
                anchors.fill: parent
                radius: 9
                border.width: 1.5
                border.color: scr.sel ? Theme.colors.accent : Theme.colors.outlineStrong
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: Theme.colors.surface3 }
                    GradientStop { position: 1; color: Theme.colors.surface2 }
                }
                Kanji {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -15
                    text: Displays.numeralOf(scr.o.name)
                    size: Math.max(10, Math.min(50, scr.height * 0.42))
                    opacity: 0.2
                }
                Rectangle {
                    visible: scr.o.name === Displays.primary && scr.o.enabled
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: 20
                    height: 20
                    radius: 5
                    color: Theme.colors.accent
                    Kanji { anchors.centerIn: parent; text: "主"; size: 12; color: Theme.colors.accentInk }
                }
                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.bottomMargin: 9
                    spacing: 0
                    OText { text: scr.o.label; size: 12.5; font.weight: Font.DemiBold; lineHeightMode: Text.FixedHeight; lineHeight: 15 }
                    OText {
                        text: !scr.o.enabled ? "apagada" : scr.o.cur
                            ? scr.o.cur.w + "×" + scr.o.cur.h + " · " + Math.round(scr.o.cur.r / 1000) + " Hz · ×" + String(scr.o.scale).replace(".", ",") : ""
                        size: 10.5
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 12
                        font.weight: Font.Medium
                        color: Theme.colors.textMuted
                        tabular: true
                    }
                }
            }
            DragHandler {
                id: drag
                target: null
                enabled: scr.movable
                onTranslationChanged: root.snapX = root.snapFor(scr.o.name, scr.modelData.x + translation.x / root.k, scr.modelData.w).guide
                onActiveChanged: {
                    if (active) {
                        root.picked(scr.o.name);
                        return;
                    }
                    root.snapX = -1;
                    const s = root.snapFor(scr.o.name, scr.modelData.x + translation.x / root.k, scr.modelData.w);
                    const ny = root.snapY(scr.o.name, scr.modelData.y + translation.y / root.k, scr.modelData.h);
                    root.place(scr.o, s.x, ny);
                }
            }
            TapHandler {
                onTapped: root.picked(scr.o.name)
            }
            Accessible.role: Accessible.Button
            Accessible.name: scr.o.label + (scr.o.name === Displays.primary ? ", principal" : "")
            Accessible.description: scr.movable ? "Flechas para moverla, Mayús para mover de 1 en 1" : ""
            HoverHandler { cursorShape: drag.enabled ? Qt.OpenHandCursor : Qt.PointingHandCursor }

            activeFocusOnTab: true
            onActiveFocusChanged: {
                if (!activeFocus)
                    return;
                root.keyFocus = o.name;
                root.picked(o.name);
            }
            Component.onCompleted: if (root.keyFocus === o.name && !(root.focused?.activeFocusOnTab ?? false)) forceActiveFocus()
            function nudge(dx: real, dy: real): void {
                kx += dx;
                ky += dy;
                keyCommit.restart();
            }
            Timer {
                id: keyCommit
                interval: 700
                onTriggered: {
                    const nx = scr.modelData.x + scr.kx, ny = scr.modelData.y + scr.ky;
                    scr.kx = 0;
                    scr.ky = 0;
                    root.place(scr.o, nx, ny);
                }
            }
            Keys.onReturnPressed: root.picked(o.name)
            Keys.onSpacePressed: root.picked(o.name)
            Keys.onPressed: e => {
                if (!movable)
                    return;
                const d = (e.modifiers & Qt.ShiftModifier) ? 1 : 10;
                if (e.key === Qt.Key_Left)
                    nudge(-d, 0);
                else if (e.key === Qt.Key_Right)
                    nudge(d, 0);
                else if (e.key === Qt.Key_Up)
                    nudge(0, -d);
                else if (e.key === Qt.Key_Down)
                    nudge(0, d);
                else
                    return;
                e.accepted = true;
            }
            FocusRing {
                radius: 13
            }
        }
    }

    // a dropped (or keyboard-moved) screen: applied as a trial when it really moved
    function place(o: var, x: real, y: real): void {
        if (Math.abs(x - o.x) > 1 || Math.abs(y - o.y) > 1)
            Displays.move(o.name, x, y);
    }

    // magnet: the dragged screen's left edge sticks to another's right edge, or its right edge to another's left
    function snapFor(name: string, lx: real, w: real): var {
        let best = { x: lx, d: 1e9, guide: -1 };
        for (const s of shown) {
            if (s.o.name === name || !s.o.enabled)
                continue;
            for (const c of [{ x: s.x + s.w, edge: s.x + s.w }, { x: s.x - w, edge: s.x }]) {
                const d = Math.abs(lx - c.x);
                if (d < best.d)
                    best = { x: c.x, d: d, guide: cx(c.edge) };
            }
        }
        return best.d < 1e9 ? best : { x: lx, d: 0, guide: -1 };
    }
    // vertical: align tops, bottoms or centres when close (60 logical px), else keep where it was dropped
    function snapY(name: string, ly: real, h: real): real {
        let best = ly, bd = 60;
        for (const s of shown) {
            if (s.o.name === name || !s.o.enabled)
                continue;
            for (const c of [s.y, s.y + s.h - h, s.y + (s.h - h) / 2]) {
                if (Math.abs(ly - c) < bd) {
                    bd = Math.abs(ly - c);
                    best = c;
                }
            }
        }
        return best;
    }
}
