pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 画面 Pantalla (mockup 12): 配置 Haichi (arrange, per-screen mode/scale/rotation/VRR/primary, modes, profiles) with
// «revertir en 15 s», brightness of each screen, 保護 Hogo, night light, touch screen and what happens on hot-plug.
SetteiPage {
    id: page
    subtitle: "Organiza tus pantallas y su brillo. Cada cambio se prueba 15 s antes de quedarse."
    resetPaths: ["display.brightness.keysTarget", "display.brightness.timeCurve", "oled", "display.nightLight"]

    property string sel: Displays.primary
    readonly property var o: Displays.byName(sel) ?? Displays.list[0] ?? null
    readonly property var br: Settings.data.display.brightness
    property bool saving: false
    property string confirmDelete: ""
    Timer {
        id: disarmDelete
        interval: 4000
        onTriggered: page.confirmDelete = ""
    }
    property string newKanji: "家"
    readonly property var profileKanji: ["家", "職", "外", "旅", "学", "遊"]

    // profile actions, shared by the pointer and the keyboard
    // two steps: the first one asks («¿borrar?»), the second (within 4 s) deletes
    function askDelete(name: string, fromKeys: bool): void {
        if (confirmDelete === name) {
            Displays.deleteProfile(name);
            confirmDelete = "";
            if (fromKeys)
                Qt.callLater(() => addProfile.forceActiveFocus());    // the chip is gone: keep the keyboard nearby
        } else {
            confirmDelete = name;
            disarmDelete.restart();
        }
    }
    function saveOrUpdate(fromKeys: bool): void {
        if (Displays.activeProfile) {
            Displays.updateProfile(Displays.activeProfile.name, Displays.activeProfile.kanji);
            Osd.show("info", 0, "Perfil actualizado", "save");
        } else {
            saving = true;
            if (fromKeys)
                Qt.callLater(() => kanjiPick.forceActiveFocus());
        }
    }
    // leaving the name form: the keyboard goes back to «Guardar perfil» when it was in the form
    function endSaving(): void {
        let kb = false;
        for (let p = page.Window.activeFocusItem; p; p = p.parent)
            if (p === savingRow)
                kb = true;
        saving = false;
        if (kb)
            Qt.callLater(() => addProfile.forceActiveFocus());
    }

    headerRight: Component {
        Chip {
            visible: Displays.activeProfile !== null
            kanji: Displays.activeProfile?.kanji ?? ""
            text: "Perfil " + (Displays.activeProfile?.name ?? "") + (Settings.data.display.autoProfile ? " · automático" : "")
            tone: "red"
        }
    }
    function esc(t: string): string {
        return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    function num(v: real): string {
        return String(Math.round(v * 100) / 100).replace(".", ",");
    }
    readonly property var transforms: [{ id: "normal", label: "Normal" }, { id: "90", label: "90°" }, { id: "180", label: "180°" },
        { id: "270", label: "270°" }, { id: "flipped", label: "Volteada" }]

    // 15 s trial banner (mock.css .banner)
    Rectangle {
        visible: Displays.trial || Displays.error !== ""
        Layout.fillWidth: true
        Layout.topMargin: 18 - 8
        Layout.bottomMargin: 14 - 4
        implicitHeight: 54
        radius: 14
        color: Theme.mix(Theme.colors.surface1, Theme.colors.accent, 0.10)
        border.width: 1
        border.color: Theme.alpha(Theme.colors.accent, 0.35)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12
            OIcon { icon: Displays.error !== "" ? "error" : "restart_alt"; size: 22; color: Theme.colors.accent }
            Text {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                color: Theme.colors.textMuted
                font.family: Theme.font.ui
                font.pointSize: 12.5 * 0.75 * Theme.font.scale
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
                text: Displays.error !== "" ? "<font color='" + Theme.colors.text + "'><b>niri no aceptó el cambio</b></font> · " + page.esc(Displays.error.split("\n")[0])
                    : "<font color='" + Theme.colors.text + "'><b>" + page.esc(Displays.trialLabel) + "</b></font> · se revierte sola en <font color='"
                      + Theme.colors.text + "'><b>" + Displays.countdown + " s</b></font> si no confirmas"
            }
            OButton { visible: Displays.trial; ghost: true; text: "Revertir"; onClicked: Displays.revert() }
            OButton { visible: Displays.trial; primary: true; text: "Mantener"; onClicked: Displays.keep() }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Displays.trial || Displays.error !== "" ? 0 : 18
        columns: 2
        columnSpacing: 14
        // left: arrange
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1.45
            padTop: 14
            padBottom: 16
            ColumnLayout {
                x: 16
                width: parent.width - 32
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Kanji { text: "配置"; size: 17; color: Theme.colors.accent }
                    OText { text: "Organizar"; size: 14.5; font.weight: Font.DemiBold }
                    OText { Layout.fillWidth: true; text: Displays.multi ? "arrastra para colocar" : "conecta un monitor para organizar"; size: 12; color: Theme.colors.textDim }
                    OButton { ghost: true; icon: "tag"; text: "Identificar"; implicitHeight: 28; onClicked: Displays.identify() }
                    OButton { ghost: true; icon: "refresh"; text: "Detectar"; implicitHeight: 28; onClicked: { Niri.refreshOutputs(); Brightness.detectAgain(); } }
                }
                HaichiCanvas {
                    Layout.fillWidth: true
                    selected: page.sel
                    onPicked: n => page.sel = n
                }
                Segmented {
                    Layout.fillWidth: true
                    enabled: Displays.multi
                    opacity: enabled ? 1 : 0.4
                    options: [{ id: "extend", kanji: "拡", label: "Extender" }]
                        .concat(Displays.mirrorAvailable ? [{ id: "mirror", kanji: "鏡", label: "Duplicar" }] : [])
                        .concat([{ id: "external", kanji: "外", label: "Solo monitor" }, { id: "internal", kanji: "内", label: "Solo portátil" }])
                    current: Displays.mode
                    onPicked: id => id === Displays.mode && id === "mirror" ? Displays.stopMirror() : Displays.setMode(id)
                }
                // profiles
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !page.saving
                    OText { text: "Perfiles"; size: 12; color: Theme.colors.textDim; rightPadding: 2 }
                    Repeater {
                        model: Object.keys(Displays.profiles)
                        delegate: Rectangle {
                            id: pc
                            required property string modelData
                            readonly property var p: Displays.profiles[modelData]
                            readonly property bool here: modelData === Displays.fingerprint
                            implicitHeight: 24
                            implicitWidth: pr.implicitWidth + 18
                            radius: 12
                            color: here ? Theme.colors.accentSoft : Theme.colors.surface2
                            border.width: here ? 0 : 1
                            border.color: Theme.colors.outline
                            opacity: here ? 1 : 0.75
                            RowLayout {
                                id: pr
                                anchors.centerIn: parent
                                spacing: 5
                                Kanji { text: pc.p.kanji; size: 12; color: pc.here ? Theme.colors.accent : Theme.colors.text }
                                OText { text: page.confirmDelete === pc.modelData ? "¿Borrar " + pc.p.name + "?" : pc.p.name; size: 11.5; font.weight: Font.Medium; color: pc.here ? Theme.colors.accent : Theme.colors.textMuted }
                                OIcon {
                                    // two taps: the first one asks («¿borrar?»), the second deletes; 32 px touch area
                                    icon: page.confirmDelete === pc.modelData ? "delete" : "close"
                                    size: 13
                                    color: page.confirmDelete === pc.modelData ? Theme.colors.error : Theme.colors.textDim
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -10
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.askDelete(pc.modelData, false)
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: pr
                                anchors.rightMargin: 16
                                cursorShape: pc.here ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (pc.here) Displays.applyProfile(pc.modelData)
                            }
                            // keyboard: Enter applies it (only the profile of these screens, like the click), Supr deletes
                            activeFocusOnTab: true
                            Keys.onReturnPressed: if (here) Displays.applyProfile(modelData)
                            Keys.onSpacePressed: if (here) Displays.applyProfile(modelData)
                            Keys.onDeletePressed: page.askDelete(modelData, true)
                            Accessible.role: Accessible.Button
                            Accessible.name: "Perfil " + p.name + (page.confirmDelete === modelData ? ", pulsa Supr otra vez para borrarlo"
                                : here ? ", Intro para aplicarlo" : ", de otras pantallas")
                            Accessible.description: "Supr para borrarlo"
                            FocusRing {}
                        }
                    }
                    Rectangle {
                        id: addProfile
                        implicitHeight: 24
                        implicitWidth: addRow.implicitWidth + 18
                        radius: 12
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.colors.outline
                        RowLayout {
                            id: addRow
                            anchors.centerIn: parent
                            spacing: 4
                            OIcon { icon: "add"; size: 16; color: Theme.colors.textMuted }
                            OText { text: Displays.activeProfile ? "Actualizar perfil" : "Guardar perfil"; size: 11.5; font.weight: Font.Medium; color: Theme.colors.textMuted }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.saveOrUpdate(false)
                        }
                        activeFocusOnTab: true
                        Keys.onReturnPressed: page.saveOrUpdate(true)
                        Keys.onSpacePressed: page.saveOrUpdate(true)
                        Accessible.role: Accessible.Button
                        Accessible.name: Displays.activeProfile ? "Actualizar perfil" : "Guardar perfil"
                        FocusRing {}
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    id: savingRow
                    Layout.fillWidth: true
                    visible: page.saving
                    spacing: 8
                    // the profile's kanji: one Tab stop, ← → choose, Enter goes on to the name
                    Item {
                        id: kanjiPick
                        implicitWidth: kanjiRow.implicitWidth
                        implicitHeight: 28
                        property real radius: 8
                        function step(d: int): void {
                            const i = page.profileKanji.indexOf(page.newKanji);
                            page.newKanji = page.profileKanji[Math.max(0, Math.min(page.profileKanji.length - 1, i + d))];
                        }
                        activeFocusOnTab: true
                        Keys.onLeftPressed: step(-1)
                        Keys.onRightPressed: step(1)
                        Keys.onReturnPressed: pname.focusInput()
                        Accessible.role: Accessible.PageTabList
                        Accessible.name: "Kanji del perfil: " + page.newKanji
                        Row {
                            id: kanjiRow
                            spacing: 8
                            Repeater {
                                model: page.profileKanji
                                delegate: Rectangle {
                                    required property string modelData
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 8
                                    color: page.newKanji === modelData ? Theme.colors.accent : Theme.colors.surface2
                                    Kanji { anchors.centerIn: parent; text: parent.modelData; size: 14; color: page.newKanji === parent.modelData ? Theme.colors.accentInk : Theme.colors.text }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.newKanji = parent.modelData }
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: modelData
                                    Accessible.checked: page.newKanji === modelData
                                }
                            }
                        }
                        FocusRing {}
                    }
                    TextInput_ {
                        id: pname
                        Layout.fillWidth: true
                        implicitHeight: 30
                        placeholder: "Casa, Oficina…"
                        onAccepted: save.clicked()
                    }
                    OButton { ghost: true; text: "Cancelar"; onClicked: page.endSaving() }
                    OButton {
                        id: save
                        primary: true
                        text: "Guardar"
                        onClicked: {
                            Displays.updateProfile(pname.text.trim() || "Perfil", page.newKanji);
                            page.endSaving();
                            pname.text = "";
                        }
                    }
                }
            }
        }
        // right: the selected screen
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            padTop: 4
            padBottom: 6
            RowLayout {
                width: parent.width
                height: 58
                spacing: 10
                OIcon { Layout.leftMargin: 18; icon: page.o?.internal ? "laptop" : "desktop_windows"; size: 22; color: Theme.colors.textMuted }
                OText { Layout.fillWidth: true; text: page.o?.label ?? "—"; size: 14.5; font.weight: Font.DemiBold }
                Chip { text: page.o?.name ?? "" }
                Chip {
                    Layout.rightMargin: 18
                    readonly property string kind: Brightness.entry(page.o?.name ?? "")?.kind ?? ""
                    text: kind === "ddc" ? "DDC/CI" : kind === "internal" ? "Interna" : kind === "soft" ? "Software" : "—"
                    tone: kind === "ddc" || kind === "internal" ? "ok" : ""
                }
            }
            SRow {
                title: "Resolución"
                minHeight: 47
                separator: true
                dimmed: !page.o?.enabled
                Dropdown {
                    readonly property var sizes: {
                        const seen = {}, out = [];
                        for (const m of page.o?.modes ?? []) {
                            const id = m.w + "x" + m.h;
                            if (!seen[id]) { seen[id] = true; out.push({ id: id, label: m.w + " × " + m.h + (m.pref ? " · nativa" : "") }); }
                        }
                        return out;
                    }
                    options: sizes
                    current: page.o?.cur ? page.o.cur.w + "x" + page.o.cur.h : ""
                    label: "Resolución"
                    menuWidth: 220
                    onPicked: id => {
                        const [w, h] = id.split("x").map(Number);
                        const best = page.o.modes.filter(m => m.w === w && m.h === h).sort((a, b) => b.r - a.r)[0];
                        Displays.setOutput(page.o.name, { mode: best }, "Resolución de " + page.o.label + ": " + w + "×" + h);
                    }
                }
            }
            SRow {
                title: "Frecuencia"
                minHeight: 47
                dimmed: !page.o?.enabled
                Dropdown {
                    options: (page.o?.modes ?? []).filter(m => page.o.cur && m.w === page.o.cur.w && m.h === page.o.cur.h)
                        .sort((a, b) => b.r - a.r).map(m => ({ id: m.r, label: (m.r / 1000).toFixed(m.r % 1000 ? 2 : 0).replace(".", ",") + " Hz" }))
                    current: page.o?.cur?.r ?? 0
                    label: "Frecuencia"
                    onPicked: id => {
                        const m = page.o.modes.find(x => x.w === page.o.cur.w && x.h === page.o.cur.h && x.r === id);
                        Displays.setOutput(page.o.name, { mode: m }, "Frecuencia de " + page.o.label + ": " + Math.round(id / 1000) + " Hz");
                    }
                }
            }
            SRow {
                title: "Escala"
                sub: page.o ? "Recomendada: " + page.num(Displays.recommendedScale(page.o)) + (page.o.inches ? " para " + page.o.inches + "″" : "") : ""
                minHeight: 47
                dimmed: !page.o?.enabled
                Dropdown {
                    options: [1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3].map(s => ({ id: s, label: page.num(s) }))
                    current: page.o ? Math.round(page.o.scale * 100) / 100 : 1
                    label: "Escala"
                    onPicked: id => Displays.setOutput(page.o.name, { scale: id }, "Escala de " + page.o.label + ": " + page.num(id))
                }
            }
            SRow {
                title: "Rotación"
                minHeight: 47
                dimmed: !page.o?.enabled
                Dropdown {
                    options: page.transforms
                    current: String(page.o?.transform ?? "normal").toLowerCase()
                    label: "Rotación"
                    onPicked: id => Displays.setOutput(page.o.name, { transform: id }, "Rotación de " + page.o.label)
                }
            }
            SRow {
                title: "VRR"
                sub: page.o?.vrrSupported ? "Frecuencia variable (cuando una app la pide)" : "Esta pantalla no la admite"
                minHeight: 47
                dimmed: !page.o?.enabled || !page.o?.vrrSupported
                Switch_ {
                    checked: page.o?.vrr ?? false
                    label: "VRR"
                    onToggled: Displays.setOutput(page.o.name, { vrr: !page.o.vrr }, "VRR de " + page.o.label + (page.o.vrr ? " apagado" : " encendido"))
                }
            }
            SRow {
                visible: Displays.multi
                title: "Activa"
                minHeight: 47
                Switch_ {
                    checked: page.o?.enabled ?? true
                    label: "Activa"
                    onToggled: {
                        // never switch off the last screen that is on
                        if (page.o.enabled && Displays.list.filter(x => x.enabled).length < 2)
                            return;
                        Displays.setOutput(page.o.name, { enabled: !page.o.enabled, mode: page.o.cur ?? page.o.modes.find(m => m.pref) ?? page.o.modes[0] },
                                           page.o.label + (page.o.enabled ? " apagada" : " encendida"));
                    }
                }
            }
            SRow {
                title: "Principal"
                sub: "Barra completa, isla y avisos"
                minHeight: 47
                dimmed: !page.o?.enabled
                Switch_ {
                    checked: page.o ? page.o.name === Displays.primary : false
                    label: "Principal"
                    onToggled: if (page.o.name !== Displays.primary) Displays.setOutput(page.o.name, { primary: true }, page.o.label + " como principal")
                }
            }
        }
    }

    SectionTitle { text: "Brillo · cada pantalla por separado" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 14
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1.45
            Repeater {
                // stable rows: entries is a new array on every change; a recreated row would drop the drag
                model: ScriptModel {
                    values: Brightness.entries
                    objectProp: "name"
                }
                delegate: SRow {
                    id: brow
                    required property var modelData
                    title: modelData.label
                    sub: modelData.kind === "internal" ? "Interna · OLED" : modelData.kind === "ddc" ? "DDC/CI" : modelData.kind === "soft" ? "Software (atenuación)" : "Sin control"
                    leadIcon: modelData.kind === "internal" ? "laptop" : "desktop_windows"
                    titleWidth: 150
                    minHeight: 56
                    HSlider {
                        Layout.fillWidth: true
                        value: brow.modelData.pct / 100
                        stepSize: 0.01
                        label: "Brillo de " + brow.modelData.label
                        onMoved: v => Brightness.set(v * 100, brow.modelData.name)
                    }
                    OText { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: Math.round(brow.modelData.pct) + " %"; size: 13; font.weight: Font.DemiBold; tabular: true }
                }
            }
        }
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            DropRow {
                title: "Teclas de brillo"
                sub: "A qué pantalla van"
                minHeight: 56
                key: "display.brightness.keysTarget"
                options: [{ id: "focused", label: "La del foco" }, { id: "internal", label: "Solo la interna" }, { id: "all", label: "Todas" }]
            }
            ToggleRow {
                title: "Brillo según la hora"
                sub: Settings.data.display.brightness.timeCurve ? "Recuerda tu brillo de día y de noche en cada pantalla" : "Curva día/noche por pantalla"
                minHeight: 56
                key: "display.brightness.timeCurve"
            }
        }
    }
    Card {
        Layout.topMargin: 10
        ToggleRow { title: "DDC/CI"; sub: Brightness.ddcAvailable ? "Brillo real de los monitores externos por el cable (ddcutil)" : "Falta ddcutil"; key: "display.brightness.ddc"; minHeight: 52 }
        ToggleRow { title: "Atenuación por software"; sub: "Si un monitor no admite DDC/CI: capa oscura (no ahorra energía)"; key: "display.brightness.softFallback"; minHeight: 52 }
        SRow {
            visible: page.o !== null && !page.o.internal
            title: "Nombre de " + (page.o?.name ?? "")
            sub: "Como aparece en la isla, Engawa y aquí"
            minHeight: 52
            TextInput_ {
                Layout.preferredWidth: 220
                implicitHeight: 32
                text: Settings.data.display.brightness.perOutput[page.o?.key ?? ""]?.alias ?? ""
                placeholder: page.o?.label ?? ""
                onAccepted: {
                    const per = JSON.parse(JSON.stringify(Settings.data.display.brightness.perOutput));
                    per[page.o.key] = Object.assign({}, per[page.o.key] ?? {}, { alias: text.trim() });
                    Settings.set("display.brightness.perOutput", per);
                    Brightness.rebuild();
                }
            }
        }
        SRow {
            visible: page.o !== null
            title: "Brillo mínimo de " + (page.o?.label ?? "")
            sub: "Las teclas y los deslizadores no bajan de aquí"
            minHeight: 52
            HSlider {
                Layout.preferredWidth: 220
                from: 0
                to: 50
                stepSize: 1
                value: Number(Settings.data.display.brightness.perOutput[page.o?.key ?? ""]?.min ?? 0)
                label: "Brillo mínimo"
                onCommitted: v => {
                    const per = JSON.parse(JSON.stringify(Settings.data.display.brightness.perOutput));
                    per[page.o.key] = Object.assign({}, per[page.o.key] ?? {}, { min: Math.round(v) });
                    Settings.set("display.brightness.perOutput", per);
                }
            }
            OText { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: Math.round(Settings.data.display.brightness.perOutput[page.o?.key ?? ""]?.min ?? 0) + " %"; size: 13; font.weight: Font.DemiBold; tabular: true }
        }
    }

    SectionTitle { text: "保護 · Cuidado del OLED" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 72
        radius: Theme.radius.card
        color: Theme.colors.surface1
        border.width: 1
        border.color: Theme.colors.outline
        RowLayout {
            anchors.fill: parent
            spacing: 0
            Repeater {
                model: [{ k: "oled.pixelShift", t: "Desplazar píxeles", s: "Barra e isla, 2 px cada 15 min" },
                        { k: "oled.dimStatic", t: "Atenuar lo estático", s: "Barra al 80 % tras 3 min" },
                        { k: "oled.lockDrift", t: "Bloqueo a la deriva", s: "Reloj y texto se mueven despacio" }]
                delegate: Item {
                    id: hg
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle { visible: hg.index > 0; width: 1; height: parent.height; color: Theme.colors.outline }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            OText { Layout.fillWidth: true; text: hg.modelData.t; size: 13.5; font.weight: Font.Medium }
                            OText { Layout.fillWidth: true; text: hg.modelData.s; size: 12; color: Theme.colors.textMuted }
                        }
                        Switch_ {
                            checked: Boolean(Settings.get(hg.modelData.k, true))
                            label: hg.modelData.t
                            onToggled: Settings.set(hg.modelData.k, !checked)
                        }
                    }
                }
            }
        }
    }

    SectionTitle { text: "Luz nocturna y táctil" }
    Card {
        SRow {
            title: "Luz nocturna"
            sub: NightLight.subtitle
            Segmented {
                Layout.preferredWidth: 380
                options: [{ id: "off", label: "Apagada" }, { id: "auto", label: "Atardecer" }, { id: "schedule", label: "Horario" }, { id: "manual", label: "Siempre" }]
                current: NightLight.mode
                onPicked: id => NightLight.setMode(id)
            }
        }
        SliderRow {
            title: "Temperatura"
            sub: "Más baja = más cálida"
            dimmed: NightLight.mode === "off"
            key: "display.nightLight.temp"
            from: 2500
            to: 5500
            stepSize: 100
            format: v => Math.round(v) + " K"
        }
        ToggleRow { title: "Pantalla táctil"; sub: "Toques y gestos en el panel del portátil"; key: "input.touch" }
    }

    SectionTitle { text: "Al conectar y desconectar" }
    Card {
        ToggleRow { title: "Aplicar perfiles solos"; sub: "Al conectar un conjunto de monitores con perfil guardado"; key: "display.autoProfile" }
        ToggleRow { title: "Preguntar con un monitor nuevo"; sub: "«Monitor conectado · Extender · Solo este · Duplicar · Organizar»"; key: "display.notifyOnConnect" }
        ToggleRow { title: "Con la tapa cerrada, todo al monitor"; sub: "Si hay un monitor conectado, el panel se apaga y vuelve al abrir (lo hace niri)"; key: "display.lidCloseToExternal" }
        ToggleRow { title: "No molestar al presentar"; sub: "Duplicar activa No molestar y Despierto, y oculta el contenido de los avisos"; key: "display.mirrorDnd" }
    }
}
