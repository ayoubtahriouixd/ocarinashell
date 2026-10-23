pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// 滑 Fluido page (mockup 13, mock.css .fstat / .rhythm / .frow; docs/02-DISENO «Página Fluido»): header with the lit
// hanko and the switch; status card (target app · window, «30 → 120 fps», chips, the 8-refresh rhythm strip); the
// multiplier; «A medida» with its slider (30 → Hz, marks on the divisors of Hz; the right end stores 0 = «the Hz»);
// engine; quality (flow scale, performance mode: «auto» while they follow the calibration), audio sync, automatic.
ColumnLayout {
    id: root
    spacing: 8
    signal back
    readonly property var cfg: Settings.data.nameraka
    readonly property bool on: Nameraka.wanted
    readonly property real hz: Math.round(Nameraka.panelMaxHz || 120)   // the panel's own maximum, not a cap of ours
    readonly property var win: Nameraka.info.window ? (Niri.windows[Nameraka.info.window] ?? null) : null

    Component.onCompleted: Nameraka.statsUsers++
    Component.onDestruction: Nameraka.statsUsers = Math.max(0, Nameraka.statsUsers - 1)

    // ── header ──────────────────────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 11
        IconButton {
            icon: "arrow_back"
            label: "Atrás"
            onClicked: root.back()
        }
        // the hanko: lit when on (mock.css .fhk.on, without speed lines here), outlined when off like Engawa's card
        Item {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            SoftShadow {
                visible: root.on
                target: headHanko
                offsetY: 0
                blur: 18
                color: Theme.alpha(Theme.colors.accent, 0.45)
            }
            Rectangle {
                id: headHanko
                anchors.fill: parent
                radius: 10
                color: root.on ? Theme.colors.accent : "transparent"
                border.width: 1.5
                border.color: root.on ? Theme.alpha(Theme.colors.onImage, 0.22) : Theme.colors.accent
                Kanji {
                    anchors.centerIn: parent
                    text: "滑"
                    brush: true
                    size: 22
                    color: root.on ? Theme.colors.surface0 : Theme.colors.accent
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            OText { Layout.fillWidth: true; text: "Nameraka"; size: 15; font.weight: Font.DemiBold }
            OText { Layout.fillWidth: true; text: "Generación de fotogramas · LSFG"; size: 12; color: Theme.colors.textMuted }
        }
        Switch_ {
            checked: root.on
            label: "Nameraka"
            enabled: Nameraka.available && !Nameraka.blocked && (!Nameraka.batteryOff || root.on)
            onToggled: Nameraka.toggle()
        }
    }

    // ── status ──────────────────────────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 6
        implicitHeight: stat.implicitHeight + 26
        radius: 16
        color: Theme.colors.surface1
        border.width: 1
        border.color: Theme.colors.outline
        ColumnLayout {
            id: stat
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                IconImage {
                    visible: root.on && Nameraka.app !== ""
                    implicitSize: 18
                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(Nameraka.app)?.icon ?? Nameraka.app, "video-x-generic")
                }
                OText {
                    text: root.on ? (Nameraka.app !== "" ? Nameraka.appName(Nameraka.app) : "—") : "Apagado"
                    size: 12.5
                    font.weight: Font.DemiBold
                }
                OText {
                    Layout.fillWidth: true
                    visible: root.on && (root.win?.title ?? "") !== ""
                    text: "· " + (root.win?.title ?? "")
                    size: 12.5
                    color: Theme.colors.textMuted
                    elide: Text.ElideRight
                }
            }
            // 30 → 120 fps
            Row {
                Layout.topMargin: 10
                spacing: 10
                OText {
                    text: Nameraka.base > 0 ? Nameraka.fmt(Nameraka.base) : "—"
                    size: 26
                    font.weight: Font.DemiBold
                    tabular: true
                    color: Theme.colors.textMuted
                }
                OIcon { anchors.verticalCenter: parent.verticalCenter; icon: "arrow_forward"; size: 20; color: Theme.colors.textDim }
                OText {
                    id: outText
                    text: root.on && Nameraka.outFps > 0 ? Math.round(Nameraka.outFps) : String(Nameraka.targetFps)
                    size: 26
                    font.weight: Font.DemiBold
                    tabular: true
                    color: root.on ? Theme.colors.accent : Theme.colors.textMuted     // off: what you would get
                }
                OText { anchors.baseline: outText.baseline; text: "fps"; size: 13; color: Theme.colors.textMuted }
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 6
                Chip {
                    text: "×" + Nameraka.m + (Nameraka.limited ? " (pedido ×" + Nameraka.chosen + ")" : root.on ? " real" : " al encender")
                    tone: root.on ? "red" : ""
                    weight: Font.DemiBold
                }
                Chip {
                    text: "LSFG 3.1 · flujo " + Math.round((Nameraka.info.flow ?? 1) * 100) + " %"
                          + (Nameraka.info.perf ? " · rendimiento" : "")
                }
                Chip {
                    visible: root.cfg.avSync && Nameraka.audioDelay > 0
                    icon: "graphic_eq"
                    tone: "ok"
                    text: "+" + Math.round(Nameraka.audioDelay) + " ms · audio sincronizado"
                }
                Chip {
                    visible: Nameraka.eco
                    text: "batería: económico"
                }
            }
            // rhythm strip: one cell per refresh (real = filled, generated = outline); redrawn only when m changes
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 5
                opacity: root.on ? 1 : 0.35          // off: the rhythm it would have, dimmed
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        readonly property int period: Math.max(1, Math.floor(root.hz / Math.max(1, Nameraka.base || 30) + 0.01))
                        readonly property int gen: Math.max(0, Math.min(period - 1, Nameraka.m - 1))
                        readonly property bool real: (index % period) < period - gen
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        radius: 4
                        color: real ? Theme.colors.accent : "transparent"
                        border.width: 1.5
                        border.color: Theme.colors.accent
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 7
                spacing: 14
                Row {
                    spacing: 5
                    opacity: root.on ? 1 : 0.35          // the legend dims with the strip
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 8; radius: 2; color: Theme.colors.accent }
                    OText { text: "real"; size: 11; color: Theme.colors.textDim }
                }
                Row {
                    spacing: 5
                    opacity: root.on ? 1 : 0.35
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 8; radius: 2
                        color: "transparent"; border.width: 1.5; border.color: Theme.colors.accent
                    }
                    OText { text: "generado"; size: 11; color: Theme.colors.textDim }
                }
                Item { Layout.fillWidth: true }
                OText {
                    text: Nameraka.warning !== "" ? "⚠ " + Nameraka.warning : root.on ? root.hz + " Hz · ritmo perfecto" : root.hz + " Hz"
                    size: 11
                    color: Nameraka.warning !== "" ? Theme.colors.warning : Theme.colors.textDim
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
            }
        }
    }

    // ── multiplier ──────────────────────────────────────────────────────────────────────────
    SectionLabel { text: "Multiplicador" }
    Segmented {
        Layout.fillWidth: true
        accent: true
        current: root.cfg.mode
        options: [
            { id: "x2", label: "×2" }, { id: "x4", label: "×4" }, { id: "x6", label: "×6" },
            { id: "custom", icon: "tune", label: Nameraka.targetFps + " fps" }
        ]
        onPicked: id => Nameraka.setMode(id)
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: custom.implicitHeight + 22
        radius: 16
        color: Theme.colors.surface1
        border.width: 1
        border.color: Theme.colors.outline
        ColumnLayout {
            id: custom
            x: 14
            y: 12
            width: parent.width - 28
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    OText { Layout.fillWidth: true; text: "A medida"; size: 13; font.weight: Font.Medium }
                    OText { Layout.fillWidth: true; text: "Los fps que quieras · por defecto, los Hz"; size: 11.5; color: Theme.colors.textMuted }
                }
                OText {
                    text: Math.round(fpsSlider.live) + " fps"
                    size: 13
                    font.weight: Font.DemiBold
                    tabular: true
                }
            }
            HSlider {
                id: fpsSlider
                Layout.fillWidth: true
                from: 30
                to: root.hz
                stepSize: 1
                label: "Fotogramas por segundo a medida"
                value: root.cfg.fps > 0 ? Math.min(root.cfg.fps, root.hz) : root.hz
                valueText: Math.round(live) + " fps"
                // the right end stores 0: «the Hz of the screen» (a 144 Hz monitor then reaches 144)
                onCommitted: v => Nameraka.setFps(Math.round(v) >= root.hz ? 0 : Math.round(v))
            }
            Item {
                Layout.fillWidth: true
                Layout.topMargin: -7
                implicitHeight: 12
                Repeater {
                    // marks on the divisors of the refresh rate (30 · 40 · 60 · 120)
                    model: [30, 40, 60, root.hz / 2, root.hz].filter((v, i, a) => v >= 30 && v <= root.hz && Number.isInteger(root.hz / v) && a.indexOf(v) === i)
                    delegate: OText {
                        required property var modelData
                        // under the knob's centre: the slider's track is inset by half a knob (9 px) each side
                        x: Math.min(parent.width - implicitWidth, Math.max(0, 9 + (modelData - 30) / Math.max(1, root.hz - 30) * (parent.width - 18) - implicitWidth / 2))
                        text: modelData
                        size: 10
                        tabular: true
                        color: Theme.colors.textDim
                    }
                }
            }
        }
    }

    // ── engine ──────────────────────────────────────────────────────────────────────────────
    SectionLabel { text: "Motor" }
    Segmented {
        Layout.fillWidth: true
        accent: true
        current: "auto"
        options: [{ id: "auto", label: "Auto" }, { id: "lsfg", label: "LSFG 3.1" },
                  { id: "ia", label: "IA", chip: "exp.", disabled: !(Nameraka.selftest.engines?.ia ?? false) }]
        onPicked: id => {
            if (id === "ia")
                Osd.show("info", 0, "IA: " + (Nameraka.selftest.engines?.iaReason ?? "no disponible"), "info");
        }
    }

    // ── quality ─────────────────────────────────────────────────────────────────────────────
    SectionLabel { text: "Calidad" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: qual.implicitHeight
        radius: 16
        color: Theme.colors.surface1
        border.width: 1
        border.color: Theme.colors.outline
        ColumnLayout {
            id: qual
            width: parent.width
            spacing: 0
            FlowRow {
                title: "Resolución del flujo"
                sub: "Menos = más rápido"
                AutoChip {
                    auto: root.cfg.flow <= 0
                    onBack: Nameraka.setQuality(0, root.cfg.perf)
                }
                HSlider {
                    Layout.preferredWidth: root.cfg.flow <= 0 ? 104 : 130   // room for the title next to the «auto» chip
                    from: 0.25
                    to: 1
                    stepSize: 0.05
                    label: "Resolución del flujo"
                    value: root.cfg.flow > 0 ? root.cfg.flow : (Nameraka.info.flow ?? 0.5)
                    onCommitted: v => Nameraka.setQuality(v, root.cfg.perf)
                }
                OText {
                    Layout.preferredWidth: 54
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((root.cfg.flow > 0 ? root.cfg.flow : (Nameraka.info.flow ?? 0.5)) * 100) + " %"
                    size: 12.5
                    font.weight: Font.DemiBold
                    tabular: true
                }
            }
            FlowRow {
                title: "Modo rendimiento"
                sub: root.cfg.perf === "auto" ? "Automático según la calibración" : "Modelo ligero, para ×6 o batería"
                separator: true
                AutoChip {
                    auto: root.cfg.perf === "auto"
                    onBack: Nameraka.setQuality(root.cfg.flow, "auto")
                }
                Switch_ {
                    checked: root.cfg.perf === "on" || (root.cfg.perf === "auto" && (Nameraka.info.perf ?? false))
                    label: "Modo rendimiento"
                    onToggled: Nameraka.setQuality(root.cfg.flow, checked ? "off" : "on")
                }
            }
            FlowRow {
                title: "Sincronizar audio"
                sub: "Retrasa el sonido lo mismo que la imagen"
                separator: true
                Switch_ {
                    checked: root.cfg.avSync
                    label: "Sincronizar audio"
                    onToggled: Settings.set("nameraka.avSync", !root.cfg.avSync)
                }
            }
            FlowRow {
                title: "Automático"
                sub: "Con vídeo a pantalla completa"
                separator: true
                Switch_ {
                    checked: root.cfg.auto
                    label: "Automático"
                    onToggled: Settings.set("nameraka.auto", !root.cfg.auto)
                }
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 6
        Chip {
            icon: "battery_5_bar"
            text: root.cfg.battery === "eco" ? "En batería: económico" : root.cfg.battery === "off" ? "En batería: apagado" : "En batería: normal"
        }
        Chip {
            icon: "speed"
            text: Nameraka.info.calibrated ? "Calibrado" + (Nameraka.panelRes !== "" ? " · " + Nameraka.panelRes : "")
                                           : "Sin calibrar · valores medidos en la 860M"
        }
    }

    // «auto» while the value follows the calibration (accent); touching the control fixes a value and the chip, now
    // neutral, gives it back to automatic
    component AutoChip: Chip {
        id: ac
        property bool auto: true
        signal back
        text: "auto"
        tone: auto ? "red" : ""
        MouseArea {
            anchors.fill: parent
            enabled: !ac.auto
            cursorShape: ac.auto ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: ac.back()
        }
    }
    component SectionLabel: OText {
        Layout.topMargin: 8
        Layout.leftMargin: 2
        size: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: Theme.colors.textDim
    }
    component FlowRow: Item {
        id: fr
        property string title
        property string sub
        property bool separator: false
        default property alias trailing: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(50, txt.implicitHeight + 16)
        Rectangle {
            visible: fr.separator
            width: parent.width
            height: 1
            color: Theme.colors.outline
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12
            ColumnLayout {
                id: txt
                Layout.fillWidth: true
                spacing: 2
                OText { Layout.fillWidth: true; text: fr.title; size: 13; font.weight: Font.Medium }
                OText { Layout.fillWidth: true; text: fr.sub; size: 11.5; color: Theme.colors.textMuted }
            }
            RowLayout {
                id: slot
                spacing: 8
            }
        }
    }
}
