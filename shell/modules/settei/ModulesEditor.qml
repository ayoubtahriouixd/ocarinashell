pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Bar modules: switch each one on/off and drag (or Alt+↑/↓) to reorder within its side. Writes bar.modules.
Card {
    id: root
    readonly property var all: [
        { id: "workspaces", side: "izquierda", icon: "view_week", t: "Espacios de trabajo", s: "Hanko rojo en el activo" },
        { id: "title", side: "izquierda", icon: "title", t: "Título de la ventana", s: "Icono y título de la ventana con foco" },
        { id: "tray", side: "derecha", icon: "apps", t: "Bandeja", s: "Iconos de las apps en segundo plano" },
        { id: "cluster", side: "derecha", icon: "wifi", t: "Estado", s: "Wi-Fi, Bluetooth, volumen, batería y perfil (abre Engawa)" },
        { id: "bell", side: "derecha", icon: "notifications", t: "Campana", s: "Centro de notificaciones" }
    ]
    readonly property var mods: (Settings.data.bar.modules ?? []).filter((m, i, a) => a.indexOf(m) === i)
    // visible ones in their order, then the hidden ones
    readonly property var entries: mods.map(id => all.find(a => a.id === id)).filter(x => !!x)
        .concat(all.filter(a => mods.indexOf(a.id) < 0))

    function toggle(id: string): void {
        const m = mods.slice();
        const i = m.indexOf(id);
        if (i >= 0)
            m.splice(i, 1);
        else
            m.push(id);
        Settings.set("bar.modules", m);
    }
    function move(id: string, d: int): void {
        moveBy(id, d, 1);
    }
    // n steps in one write
    function moveBy(id: string, d: int, n: int): void {
        let m = mods.slice();
        for (let k = 0; k < n; k++)
            m = stepOnce(m, id, d);
        if (JSON.stringify(m) !== JSON.stringify(mods))
            Settings.set("bar.modules", m);
    }
    function stepOnce(m: var, id: string, d: int): var {
        const i = m.indexOf(id);
        const side = all.find(a => a.id === id).side;
        let j = i + d;
        while (j >= 0 && j < m.length && all.find(a => a.id === m[j]).side !== side)
            j += d;
        if (i < 0 || j < 0 || j >= m.length)
            return m;
        m.splice(i, 1);
        m.splice(j, 0, id);
        return m;
    }

    Repeater {
        model: root.entries
        delegate: SRow {
            id: r
            required property var modelData
            required property int index
            readonly property bool shown: root.mods.indexOf(modelData.id) >= 0
            title: modelData.t
            sub: modelData.s + " · " + modelData.side
            leadIcon: modelData.icon
            minHeight: 58
            z: drag.active ? 10 : 0
            transform: Translate { y: drag.active ? drag.translation.y : 0 }
            Keys.onPressed: e => {
                if (e.modifiers & Qt.AltModifier && (e.key === Qt.Key_Up || e.key === Qt.Key_Down)) {
                    root.move(modelData.id, e.key === Qt.Key_Up ? -1 : 1);
                    e.accepted = true;
                }
            }
            OIcon {
                visible: r.shown
                icon: "drag_indicator"
                size: 20
                color: Theme.colors.textDim
                DragHandler {
                    id: drag
                    target: null
                    yAxis.enabled: true
                    xAxis.enabled: false
                    onActiveChanged: if (!active) {
                        const steps = Math.round(translation.y / r.height);
                        if (steps !== 0)
                            root.moveBy(r.modelData.id, steps > 0 ? 1 : -1, Math.abs(steps));
                    }
                }
                HoverHandler { cursorShape: Qt.OpenHandCursor }
            }
            Switch_ {
                checked: r.shown
                label: r.modelData.t
                onToggled: root.toggle(r.modelData.id)
            }
        }
    }
}
