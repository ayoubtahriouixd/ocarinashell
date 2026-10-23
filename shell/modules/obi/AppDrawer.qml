pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// 器 Utsuwa — the ocarina's app drawer (Ayoub, fase 16: «diseño que me deje wow»). A glass panel that springs out of
// the ocarina: rail of categories (kanji hanko like Settei), the frequent apps as large tiles, then every app A→Z
// with its initial; typing filters with the matched letters in red; ↑↓←→ move on the real grid, Enter opens,
// Tab / right click → the app's actions and «Fijar» (↑↓ move, Enter/Space run, Esc/Tab close only the menu). Data:
// services/Apps (one index with Torii). Its own full-screen layer surface (ocarina-apps, Overlay, exclusive keyboard)
// that exists only while open; Motion.enabled = false → it simply appears and disappears. Opened by click on the
// ocarina or by `ocarina apps` (Mod+D → IPC `apps toggle`) the same way: it was an xdg_popup of the bar with a grab,
// and Wayland refuses a grab without a recent input on the bar (the keyboard path never opened, fase 17). A click
// outside the glass closes it, the search field takes the focus on creation.
Item {
    id: root

    required property Item anchorItem
    property bool shown: false
    property bool closing: false

    function toggle(): void {
        if (shown && !closing)
            close();
        else if (!shown)
            shown = true;
    }
    function close(): void {
        if (!shown || closing)
            return;
        if (!Motion.enabled) {
            shown = false;
            return;
        }
        closing = true;
    }

    LazyLoader {
        active: root.shown
        PanelWindow {
            id: popup
            readonly property var barWindow: root.anchorItem.QsWindow.window
            screen: barWindow ? barWindow.screen : null
            WlrLayershell.namespace: "ocarina-apps"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"

            // under the ocarina, in screen coordinates: the bar surface's margins + the mark's place in it (what the
            // popup anchor did: 2 px below, the glass 20 px to the left of the mark, slid back inside the screen)
            readonly property point origin: {
                const m = barWindow && barWindow.margins ? barWindow.margins : { left: 0, top: 0 };
                const at = root.anchorItem.mapToItem(null, 0, root.anchorItem.height);
                return Qt.point((m.left ?? 0) + at.x, (m.top ?? 0) + at.y);
            }
            // a click outside the glass closes it (the popup grab did this before)
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            readonly property int pad: 14            // room for the shadow around the glass
            readonly property int cols: 5
            property string query: ""
            property string cat: "all"
            property int sel: 0                      // index into `order`
            property int menuFor: -1                 // tile whose actions are open
            property int menuSel: 0                  // highlighted row of that menu (keyboard and hover)
            property bool fresh: true                // the opening cascade, only once

            // ── the model: rows of tiles (+ headers), and the flat order the keyboard walks ──
            readonly property var res: Apps.results(query, cat, Theme.colors.accent.toString())
            readonly property bool showFrequent: query === "" && cat === "all" && Apps.frequent.length > 0
            readonly property var layout: {
                const rows = [], order = [];
                const add = (items, big) => {
                    for (let i = 0; i < items.length; i += big ? 6 : cols) {
                        const slice = items.slice(i, i + (big ? 6 : cols));
                        // each tile carries its own result: no lookup from the delegate into another list
                        rows.push({ type: "tiles", big: big, items: slice.map(r => { order.push(r); return { i: order.length - 1, r: r }; }) });
                    }
                };
                if (showFrequent) {
                    rows.push({ type: "header", text: "Frecuentes", kanji: "近" });
                    add(Apps.frequent.map(a => ({ app: a, html: a.name })), true);
                    rows.push({ type: "header", text: "Todas las apps", kanji: "全" });
                }
                if (query === "" && cat !== "recent") {
                    let letter = "", group = [];
                    const flush = () => {
                        if (group.length) {
                            rows.push({ type: "letter", text: letter });
                            add(group, false);
                        }
                    };
                    for (const r of res) {
                        const l = r.app.name.charAt(0).toLocaleUpperCase();
                        if (l !== letter) {
                            flush();
                            letter = l;
                            group = [];
                        }
                        group.push(r);
                    }
                    flush();
                } else {
                    add(res, false);
                }
                return { rows: rows, order: order };
            }
            readonly property var order: layout.order
            onQueryChanged: { sel = 0; menuFor = -1; list.positionViewAtBeginning(); }
            onCatChanged: { sel = 0; menuFor = -1; fresh = false; list.positionViewAtBeginning(); }

            // where a tile sits: [row, col]
            function where(i: int): var {
                const rows = layout.rows;
                for (let r = 0; r < rows.length; r++)
                    if (rows[r].type === "tiles") {
                        const c = rows[r].items.findIndex(t => t.i === i);
                        if (c >= 0)
                            return [r, c];
                    }
                return [-1, -1];
            }
            function vertical(d: int): void {
                const [r, c] = where(sel);
                const rows = layout.rows;
                for (let k = r + d; k >= 0 && k < rows.length; k += d)
                    if (rows[k].type === "tiles") {
                        sel = rows[k].items[Math.min(c, rows[k].items.length - 1)].i;
                        list.positionViewAtIndex(k, ListView.Contain);
                        return;
                    }
            }
            function horizontal(d: int): void {
                if (order.length === 0)
                    return;
                sel = Math.max(0, Math.min(order.length - 1, sel + d));
                list.positionViewAtIndex(where(sel)[0], ListView.Contain);
            }
            function launch(i: int): void {
                const r = order[i];
                if (!r)
                    return;
                Apps.launch(r.app);
                root.close();
            }

            // ── the actions menu: open · the app's desktop actions · pin ──
            readonly property var menuItems: {
                const r = order[menuFor] ?? null;
                if (!r)
                    return [];
                return [{ name: "Abrir", icon: "open_in_new", act: null }]
                    .concat((r.app.actions ?? []).map(a => ({ name: a.name, icon: "bolt", act: a })))
                    .concat([{ name: Apps.isPinned(r.app.id) ? "Quitar de frecuentes" : "Fijar en frecuentes",
                               icon: "push_pin", act: "pin" }]);
            }
            onMenuForChanged: menuSel = 0
            function moveMenu(d: int): void {
                const n = menuItems.length;
                if (n > 0)
                    menuSel = (menuSel + d + n) % n;
            }
            function runMenu(k: int): void {
                const r = order[menuFor] ?? null;
                const it = menuItems[k];
                if (!r || !it)
                    return;
                if (it.act === "pin") {
                    Apps.togglePin(r.app.id);
                    menuFor = -1;
                } else if (it.act) {
                    Apps.runAction(r.app, it.act);
                    root.close();
                } else {
                    launch(menuFor);
                }
            }

            // ── open / close: the glass springs out of the ocarina (top-left), the content fades with it ──
            Item {
                id: panel
                x: Math.max(popup.pad, Math.min(popup.origin.x - 20, popup.width - width - popup.pad))
                y: popup.origin.y + 2
                width: 800
                height: 600
                transformOrigin: Item.TopLeft
                // clicks on the glass itself never reach the close-on-outside area underneath
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }
                scale: Motion.enabled ? 0.9 : 1
                opacity: Motion.enabled ? 0 : 1
                Component.onCompleted: if (Motion.enabled) openAnim.start()
                ParallelAnimation {
                    id: openAnim
                    NumberAnimation { target: panel; property: "scale"; to: 1; duration: Motion.d(Motion.drawer.open)
                                      easing.type: Easing.OutBack; easing.overshoot: Motion.drawer.overshoot }
                    Anim { target: panel; property: "opacity"; to: 1; ms: Motion.fast }
                }
                ParallelAnimation {
                    running: root.closing
                    Anim { target: panel; property: "scale"; to: 0.94; ms: Motion.fast; easing.bezierCurve: Motion.accel }
                    Anim { target: panel; property: "opacity"; to: 0; ms: Motion.fast; easing.bezierCurve: Motion.accel }
                    onFinished: { root.closing = false; root.shown = false; }
                }

                PanelSurface {
                    anchors.fill: parent
                    alpha: Theme.glassOpaqueAlpha

                    // 紅 a warm wash from the top-left corner, in the panel's own shape (no clipping seams)
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.panel
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.alpha(Theme.colors.accent, 0.10) }
                            GradientStop { position: 0.32; color: "transparent" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.panel
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.alpha(Theme.colors.accent, 0.05) }
                            GradientStop { position: 0.4; color: "transparent" }
                        }
                    }
                    // the watermark
                    Kanji {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 18
                        anchors.bottomMargin: 30
                        text: "器"
                        size: 230
                        color: Theme.alpha(Theme.colors.text, 0.03)
                        visible: Settings.data.appearance.kanjiDecor
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        // ── header: hanko · title · search ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Item {
                                implicitWidth: 40
                                implicitHeight: 40
                                Rectangle {
                                    anchors.fill: hanko
                                    anchors.margins: -4
                                    anchors.topMargin: -2
                                    anchors.bottomMargin: -8
                                    radius: 14
                                    color: Theme.alpha(Theme.colors.accent, 0.2)
                                }
                                Rectangle {
                                    id: hanko
                                    anchors.fill: parent
                                    radius: Theme.radius.control + 1
                                    color: Theme.colors.accent
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: Theme.alpha(Theme.colors.accentInk, 0.22)
                                    }
                                    Kanji {
                                        anchors.centerIn: parent
                                        text: "器"
                                        size: 20
                                        color: Theme.colors.accentInk
                                    }
                                }
                            }
                            ColumnLayout {
                                spacing: 1
                                OText {
                                    text: "Aplicaciones"
                                    size: 18
                                    font.weight: Font.DemiBold
                                }
                                OText {
                                    text: Apps.all.length + " instaladas" + (Apps.frequent.length ? " · " + Apps.frequent.length + " frecuentes" : "")
                                    size: Theme.font.meta
                                    color: Theme.colors.textMuted
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: 320
                                Layout.preferredHeight: 40
                                radius: Theme.radius.control + 2
                                color: Theme.colors.surface2
                                border.width: 1
                                border.color: search.editing ? Theme.alpha(Theme.colors.accent, 0.6) : Theme.colors.outline
                                Behavior on border.color { CAnim {} }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    OIcon {
                                        icon: "search"
                                        size: 18
                                        color: Theme.colors.textMuted
                                    }
                                    TextInput_ {
                                        id: search
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        placeholder: "Buscar app…"
                                        bare: true                  // the capsule around it draws the focus
                                        // the inner TextInput, not this frame: typing must reach it with no click
                                        Component.onCompleted: focusInput()
                                        onTextChanged: popup.query = text
                                        onAccepted: popup.launch(popup.sel)
                                        // keys the TextInput leaves alone bubble up here (the open menu has its own)
                                        Keys.onPressed: ev => {
                                            if (ev.key === Qt.Key_Escape) root.close();
                                            else if (ev.key === Qt.Key_Down) popup.vertical(1);
                                            else if (ev.key === Qt.Key_Up) popup.vertical(-1);
                                            else if (ev.key === Qt.Key_Right && search.text === "") popup.horizontal(1);
                                            else if (ev.key === Qt.Key_Left && search.text === "") popup.horizontal(-1);
                                            else if (ev.key === Qt.Key_Tab) { if (popup.order.length > 0) popup.menuFor = popup.sel; }
                                            else if (ev.key === Qt.Key_PageDown || ev.key === Qt.Key_PageUp) {
                                                const c = Apps.categories;
                                                const i = c.findIndex(x => x.id === popup.cat);
                                                popup.cat = c[(i + (ev.key === Qt.Key_PageDown ? 1 : -1) + c.length) % c.length].id;
                                            } else return;
                                            ev.accepted = true;
                                        }
                                    }
                                    Kbd {
                                        visible: search.text === ""
                                        text: "Super+D"
                                        opacity: 0.7
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.colors.outline
                        }

                        // ── body: rail · grid ──
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 14

                            ColumnLayout {
                                Layout.preferredWidth: 176
                                Layout.fillWidth: false      // a nested layout fills by default: the grid gets the rest
                                Layout.fillHeight: true
                                spacing: 2
                                Repeater {
                                    model: Apps.categories
                                    delegate: DrawerCategory {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        kanji: modelData.kanji
                                        label: modelData.label
                                        count: Apps.counts[modelData.id] ?? 0
                                        selected: popup.cat === modelData.id && popup.query === ""
                                        onActivated: {
                                            popup.cat = modelData.id;
                                            search.text = "";
                                            search.focusInput();
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: Theme.colors.outline
                            }

                            ListView {
                                id: list
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: popup.layout.rows
                                cacheBuffer: 400
                                delegate: Item {
                                    id: rowItem
                                    required property var modelData
                                    required property int index
                                    width: list.width
                                    height: modelData.type === "header" ? 30 : modelData.type === "letter" ? 24
                                          : modelData.big ? 116 : 98
                                    OText {
                                        visible: rowItem.modelData.type === "header"
                                        y: 8
                                        text: (rowItem.modelData.kanji ?? "") + "  " + (rowItem.modelData.text ?? "")
                                        size: Theme.font.caption - 0.5
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 11 * 0.09
                                        font.capitalization: Font.AllUppercase
                                        color: Theme.colors.textDim
                                    }
                                    OText {
                                        visible: rowItem.modelData.type === "letter"
                                        x: 8
                                        y: 4
                                        text: rowItem.modelData.text ?? ""
                                        size: Theme.font.small
                                        font.weight: Font.DemiBold
                                        color: Theme.colors.accent
                                        opacity: 0.85
                                    }
                                    Row {
                                        visible: rowItem.modelData.type === "tiles"
                                        Repeater {
                                            model: rowItem.modelData.type === "tiles" ? rowItem.modelData.items : []
                                            delegate: AppTile {
                                                id: t
                                                required property var modelData      // { i: index in order, r: result }
                                                app: modelData.r.app
                                                html: modelData.r.html
                                                big: rowItem.modelData.big
                                                width: list.width / (rowItem.modelData.big ? 6 : popup.cols)
                                                selected: popup.sel === modelData.i
                                                cascade: popup.fresh ? modelData.i : -1
                                                onHovered: popup.sel = t.modelData.i
                                                onActivated: popup.launch(t.modelData.i)
                                                onMenuRequested: { popup.sel = t.modelData.i; popup.menuFor = t.modelData.i; }
                                            }
                                        }
                                    }
                                }
                                OText {
                                    anchors.centerIn: parent
                                    visible: popup.order.length === 0
                                    text: popup.query !== "" ? "Ninguna app coincide con «" + popup.query + "»" : "Nada aquí todavía"
                                    color: Theme.colors.textDim
                                }
                            }
                        }

                        // ── footer: keys · Torii ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            KeyHint { keys: ["↑", "↓", "←", "→"]; text: "moverse" }
                            KeyHint { keys: ["↵"]; text: "abrir" }
                            KeyHint { keys: ["Tab"]; text: "acciones" }
                            KeyHint { keys: ["Esc"]; text: "cerrar" }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: toriiRow.implicitWidth + 20
                                radius: Theme.radius.control
                                color: toriiArea.containsMouse ? Theme.colors.surface2 : "transparent"
                                RowLayout {
                                    id: toriiRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Kanji { text: "鳥居"; size: 12; color: Theme.colors.textMuted }
                                    OText { text: "Torii: todo lo demás"; size: Theme.font.meta; color: Theme.colors.textMuted }
                                }
                                MouseArea {
                                    id: toriiArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.close();
                                        Quickshell.execDetached([Paths.bin + "/ocarina", "launcher"]);
                                    }
                                }
                            }
                        }
                    }

                    // ── the actions of one app (Tab or right click): open · its desktop actions · pin ──
                    MouseArea {
                        anchors.fill: parent
                        visible: popup.menuFor >= 0
                        onClicked: popup.menuFor = -1
                    }
                    Rectangle {
                        id: menu
                        readonly property var r: popup.order[popup.menuFor] ?? null
                        visible: popup.menuFor >= 0 && r !== null
                        // while open the menu holds the keyboard (Space must not type into the search)
                        onVisibleChanged: {
                            if (visible)
                                forceActiveFocus();
                            else if (root.shown && !root.closing)     // not while the drawer is going away
                                search.focusInput();
                        }
                        Keys.onPressed: ev => {
                            if (ev.key === Qt.Key_Down) popup.moveMenu(1);
                            else if (ev.key === Qt.Key_Up) popup.moveMenu(-1);
                            else if (ev.key === Qt.Key_Home) popup.menuSel = 0;
                            else if (ev.key === Qt.Key_End) popup.menuSel = Math.max(0, popup.menuItems.length - 1);
                            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space)
                                popup.runMenu(popup.menuSel);
                            else if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_Tab || ev.key === Qt.Key_Backtab)
                                popup.menuFor = -1;
                            else return;
                            ev.accepted = true;
                        }
                        Accessible.role: Accessible.PopupMenu
                        Accessible.name: r ? "Acciones de " + r.app.name : ""
                        anchors.centerIn: parent
                        width: 300
                        height: menuCol.implicitHeight + 16
                        radius: Theme.radius.menu
                        color: Theme.colors.surface1
                        border.width: 1
                        border.color: Theme.colors.outline
                        SoftShadow {
                            target: menu
                            offsetY: 10
                            blur: 30
                            color: Theme.alpha(Theme.colors.shadow, 0.5)
                        }
                        ColumnLayout {
                            id: menuCol
                            x: 8
                            y: 8
                            width: parent.width - 16
                            spacing: 2
                            OText {
                                Layout.fillWidth: true
                                Layout.margins: 6
                                text: menu.r ? menu.r.app.name : ""
                                font.weight: Font.DemiBold
                            }
                            Repeater {
                                model: popup.menuItems
                                // one highlight for keyboard and hover, in the accent like the selected tile
                                delegate: Rectangle {
                                    id: mi
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: popup.menuSel === index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: Theme.radius.control
                                    color: selected ? Theme.alpha(Theme.colors.accent, 0.12) : "transparent"
                                    border.width: selected ? 1.5 : 0
                                    border.color: Theme.alpha(Theme.colors.accent, 0.7)
                                    Behavior on color { CAnim { ms: Motion.fast } }
                                    Accessible.role: Accessible.MenuItem
                                    Accessible.name: modelData.name
                                    Accessible.selected: selected
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        spacing: 10
                                        OIcon {
                                            icon: mi.modelData.icon
                                            size: 17
                                            color: mi.selected ? Theme.colors.accent : Theme.colors.textMuted
                                        }
                                        OText {
                                            Layout.fillWidth: true
                                            text: mi.modelData.name
                                            size: Theme.font.body
                                            font.weight: mi.selected ? Font.Medium : Font.Normal
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: popup.menuSel = mi.index
                                        onClicked: popup.runMenu(mi.index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // the cascade is for the opening only (Motion.enabled = false → no cascade, dropped at once)
            Timer {
                interval: Motion.d(Motion.drawer.cascadeEnd)
                running: true
                onTriggered: popup.fresh = false
            }
        }
    }
}
