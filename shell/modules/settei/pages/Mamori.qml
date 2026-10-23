pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 守 Mantenimiento (fase 16, mockup 10, docs/06 capa 6): what Mamori did and decided, the health of the machine,
// undo / weekly report / pause; below the mockup: holds with «Liberar ahora», the autopilot's switches and
// 控 Copias (Hikae, D-070). Everything comes from bin/ocarina-mamori's state files (services/Mamori).
SetteiPage {
    id: page
    subtitle: "El sistema se cuida solo: investiga, actualiza con snapshot, prueba y, si algo falla, vuelve atrás."
    resetPaths: []
    readonly property var m: Settings.data.mamori
    readonly property var h: Mamori.health
    readonly property var snakeModel: Snake.models.find(x => x.default) ?? null
    readonly property var emptyTitles: ["Sin actividad todavía", "Nada retenido"]

    headerRight: Component {
        Chip {
            text: !Mamori.cfg.enabled ? "Mamori apagado" : !Mamori.installed ? "Sin datos todavía"
                : Mamori.paused ? "En pausa" : Mamori.running ? "Trabajando" : !Mamori.alive ? "Sin revisar desde hace días"
                : "Mamori activo"
            tone: Mamori.active ? "ok" : ""
        }
    }

    Component.onCompleted: {
        Mamori.reload();
        Snake.refresh();
        Snake.loadModels();
    }
    // leaving the page = you have seen what it showed: the sidebar badge and the headline count only newer things
    Component.onDestruction: Mamori.markSeen()

    // ── status + Snake ──
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 22                 // mockup .sub margin-bottom 22 (the subtitle's -4 and the spacing cancel out)
        spacing: 14

        Rectangle {
            id: stateCard
            Layout.fillWidth: true
            Layout.preferredWidth: 1.25
            Layout.fillHeight: true
            implicitHeight: stateCol.implicitHeight + 36
            radius: Theme.radius.card
            border.width: 1
            border.color: Theme.colors.outline
            readonly property color tint: Mamori.tone === "warn" ? Theme.colors.accent
                : Mamori.tone === "hold" ? Theme.colors.warning : Mamori.tone === "ok" ? Theme.colors.success
                : Theme.colors.surface1
            color: Theme.colors.surface1
            // mockup 10: linear-gradient(135deg, tint 12 %, surface1 70 %). CSS's gradient line for 135° in a W×H box
            // runs from ((W−H)/4, (H−W)/4) to ((3W+H)/4, (W+3H)/4); inset 1 px so the border stays on top
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: (stateCard.width - stateCard.height) / 4
                        y1: (stateCard.height - stateCard.width) / 4
                        x2: (3 * stateCard.width + stateCard.height) / 4
                        y2: (stateCard.width + 3 * stateCard.height) / 4
                        GradientStop { position: 0; color: Qt.tint(Theme.colors.surface1, Theme.alpha(stateCard.tint, 0.12)) }
                        GradientStop { position: 0.7; color: Theme.colors.surface1 }
                    }
                    PathRectangle {
                        x: 1
                        y: 1
                        width: stateCard.width - 2
                        height: stateCard.height - 2
                        radius: stateCard.radius - 1
                    }
                }
            }
            ColumnLayout {
                id: stateCol
                x: 20
                y: 18
                width: parent.width - 40
                spacing: 16
                RowLayout {
                    spacing: 12
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Theme.radius.control
                        color: Theme.colors.accent
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.control
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.alpha(Theme.colors.accentInk, 0.22)
                        }
                        Kanji {
                            anchors.centerIn: parent
                            text: "守"
                            size: 22
                            color: Theme.colors.accentInk
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        OText {
                            text: Mamori.headline
                            size: 20
                            font.weight: Font.DemiBold
                        }
                        OText {
                            Layout.fillWidth: true
                            text: Mamori.detail
                            size: Theme.font.small
                            color: Theme.colors.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Chip {
                        icon: "inventory_2"
                        iconSize: 16
                        text: Mamori.holdList.length === 1 ? "1 retención" : Mamori.holdList.length + " retenciones"
                    }
                    Chip {
                        icon: "verified"
                        iconSize: 16
                        text: (Mamori.st.openCves ?? 0) + ((Mamori.st.openCves ?? 0) === 1 ? " CVE abierta" : " CVE abiertas")
                    }
                    Chip {
                        icon: "schedule"
                        iconSize: 16
                        text: "maduración " + (Mamori.st.maturationDays ?? page.m.maturationDays) + " días"
                    }
                    Chip {
                        visible: Mamori.attention > 0 && !Mamori.headline.endsWith("para mirar")    // not twice
                        icon: "priority_high"
                        tone: Mamori.tone === "warn" ? "red" : "warn"
                        text: Mamori.attention + (Mamori.attention === 1 ? " cosa para mirar" : " cosas para mirar")
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            implicitHeight: snakeCol.implicitHeight + 32
            radius: Theme.radius.card
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline
            ColumnLayout {
                id: snakeCol
                x: 18
                y: 16
                width: parent.width - 36
                spacing: 12
                RowLayout {
                    spacing: 10
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: Theme.radius.control
                        color: Theme.colors.surface3
                        Kanji {
                            anchors.centerIn: parent
                            text: "蛇"
                            size: 17
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        OText {
                            text: "Snake · IA local"
                            size: 14
                            font.weight: Font.DemiBold
                        }
                        OText {
                            Layout.fillWidth: true
                            text: page.m.ai === "off" || !Settings.data.snake.enabled ? "Desactivada · Mamori en modo determinista"
                                : (Snake.name || "—") + " · " + (Settings.data.snake.backend === "npu" ? "NPU" : "Vulkan") + " · "
                                  + (Snake.loaded ? "cargado" : "0 MB en reposo")
                            size: Theme.font.meta
                            color: Theme.colors.textMuted
                            elide: Text.ElideRight
                        }
                    }
                    Chip {
                        visible: (page.snakeModel?.eval?.score ?? 0) > 0
                        tone: "ok"
                        text: Math.round(page.snakeModel?.eval?.score ?? 0) + " %"
                    }
                }
                OText {
                    Layout.fillWidth: true
                    text: page.m.ai === "off" ? "Sin IA, Mamori madura 7 días los paquetes críticos y en el AUR solo acepta diferencias triviales. Nada deja de funcionar."
                        : (page.snakeModel?.eval?.score ? "Superó la evaluación propia de 38 casos. " : "")
                          + "Revisa noticias, changelogs, incidencias y PKGBUILD; propone, nunca ejecuta."
                    size: Theme.font.small
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 18.75                // 12.5 × 1.5 (a proportional 1.5 multiplies Geist's own line box)
                    color: Theme.colors.textMuted
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    maximumLineCount: 4
                }
            }
        }
    }

    // ── activity ──
    SectionTitle { text: "Actividad" }
    Card {
        padTop: 2
        padBottom: 4
        Repeater {
            model: Mamori.events.slice(0, 5)
            delegate: Item {
                id: ev
                required property var modelData
                required property int index
                width: parent?.width ?? 0
                implicitHeight: evRow.implicitHeight + 23      // the 1 px divider inside the row, as in the CSS
                readonly property var e: modelData
                Accessible.role: Accessible.StaticText
                Accessible.name: e.title + ", " + e.detail + ", " + Mamori.stamp(e.at)
                Rectangle {
                    visible: ev.index > 0
                    x: 18
                    width: parent.width - 36
                    height: 1
                    color: Theme.colors.outline
                }
                RowLayout {
                    id: evRow
                    x: 18
                    y: 12
                    width: parent.width - 36
                    spacing: 12
                    OIcon {
                        fill: true
                        size: 20
                        icon: ev.e.kind === "firmware" ? "memory" : ev.e.kind === "review" ? "travel_explore"
                            : ev.e.kind === "repair" && ev.e.result === "ok" ? "build_circle"
                            : ev.e.kind === "rollback" ? "undo"
                            : ev.e.result === "ok" ? "check_circle" : ev.e.result === "hold" ? "pause_circle"
                            : ev.e.result === "fail" ? "cancel" : ev.e.result === "attention" ? "error" : "info"
                        color: ev.e.kind === "firmware" ? Theme.colors.accent2 : ev.e.kind === "review" ? Theme.colors.info
                            : ev.e.result === "ok" ? Theme.colors.success : ev.e.result === "hold" ? Theme.colors.warning
                            : ev.e.result === "fail" ? Theme.colors.accent : ev.e.result === "attention" ? Theme.colors.warning
                            : Theme.colors.textMuted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        OText {
                            Layout.fillWidth: true
                            text: ev.e.title
                            size: Theme.font.body
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 17.55          // 13.5 × 1.3
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        OText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: ev.e.detail ?? ""
                            size: Theme.font.small
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 17.5           // 12.5 × 1.4
                            color: Theme.colors.textMuted
                            elide: Text.ElideRight
                        }
                    }
                    OText {
                        text: Mamori.stamp(ev.e.at)
                        size: Theme.font.meta
                        tabular: true
                        color: Theme.colors.textDim
                    }
                }
            }
        }
        SRow {
            visible: Mamori.events.length === 0
            title: page.emptyTitles[0]       // not a literal: the search index must not point at a hidden row
            sub: "El primer ciclo llega esta noche a las 04:00 (o cuando lleves 15 min fuera con el cargador)"
        }
    }

    // ── health ──
    SectionTitle { text: "Salud" }
    GridLayout {
        Layout.fillWidth: true
        columns: 5
        columnSpacing: 10
        rowSpacing: 10
        StatTile {
            icon: "hard_drive"
            value: page.h.disk != null ? page.h.disk + " %" : "—"
            label: "Disco · " + (page.h.diskUsed ? Math.round(page.h.diskUsed / 1073741824) + "/"
                                 + Math.round(page.h.diskSize / 1073741824) + " GiB" : "uso")
        }
        StatTile {
            icon: "speed"
            value: page.h.ssd != null ? page.h.ssd + " %" : "—"
            label: "SSD · salud NVMe"
        }
        StatTile {
            icon: "battery_5_bar"
            value: page.h.battery != null ? page.h.battery + " %" : "—"
            label: "Batería · salud"
        }
        StatTile {
            icon: "thermostat"
            value: page.h.cpuTemp != null ? page.h.cpuTemp + "°" : "—"
            label: "CPU · en reposo"
        }
        StatTile {
            icon: "history"
            value: page.h.snapshots != null ? String(page.h.snapshots) : "—"
            label: "Snapshots" + (page.h.snapshotsDays != null ? " · " + page.h.snapshotsDays + " días" : "")
        }
    }

    RowLayout {
        Layout.topMargin: 20 - 4
        spacing: 10
        OButton {
            icon: "undo"
            text: "Deshacer la última actualización"
            enabled: !Mamori.running && Tools.has("ghostty")
            onClicked: Mamori.undo()
        }
        OButton {
            ghost: true
            icon: "description"
            text: Mamori.weeklyBusy ? "Generando…" : "Informe semanal"
            enabled: !Mamori.weeklyBusy
            onClicked: Mamori.weekly()
        }
        OButton {
            ghost: true
            icon: Mamori.paused ? "play_arrow" : "pause"
            text: Mamori.paused ? "Reanudar" : "Pausar 7 días"
            onClicked: Mamori.paused ? Mamori.resume() : Mamori.pause(7)
        }
        OButton {
            ghost: true
            icon: "refresh"
            text: Mamori.running ? "Revisando…" : "Revisar ahora"
            enabled: !Mamori.running && !Mamori.paused && page.m.enabled
            onClicked: Mamori.runNow()
        }
    }

    // ── below the mockup: holds, switches, Hikae ──
    SectionTitle { text: "Retenciones" }
    Card {
        Repeater {
            model: Mamori.holdList
            delegate: SRow {
                id: hrow
                required property var modelData
                title: modelData.name + (modelData.version ? " " + modelData.version : "")
                sub: (modelData.kind === "user" ? "Retenido por ti" : "Retenido por Mamori") + " hasta el "
                    + Mamori.date(modelData.until) + (modelData.reason ? " · " + modelData.reason : "")
                OButton {
                    text: "Liberar ahora"
                    onClicked: Mamori.unhold(hrow.modelData.name)
                }
            }
        }
        SRow {
            visible: Mamori.holdList.length === 0
            title: page.emptyTitles[1]
            sub: "Retener un paquete retrasa todo su lote (nunca actualizaciones a medias); solo los kernels se retienen solos"
        }
    }

    SectionTitle { text: "Piloto automático" }
    Card {
        ToggleRow {
            title: "Piloto automático"
            sub: "Revisa cada noche a las 04:00 y cuando llevas 15 min fuera; instala solo con cargador, red sin límite y sin llamadas, juegos ni grabaciones"
            key: "mamori.enabled"
        }
        DropRow {
            title: "Inteligencia"
            sub: "Quién investiga noticias, changelogs y PKGBUILD y adapta el código si algo se rompe"
            key: "mamori.ai"
            options: [{ id: "snake", label: "蛇 Snake (local)" }, { id: "both", label: "Snake + Claude Code" },
                      { id: "claude", label: "Claude Code" }, { id: "off", label: "Ninguna (determinista)" }]
        }
        DropRow {
            title: "Con batería"
            sub: "Solo con cargador es lo más seguro: una actualización cortada por quedarse sin batería es lo único que no se deshace solo"
            key: "mamori.batteryMin"
            options: [{ id: 0, label: "Nunca" }, { id: 80, label: "Desde 80 %" }, { id: 50, label: "Desde 50 %" }]
        }
        SliderRow {
            title: "Maduración de paquetes críticos"
            sub: "Kernel, Mesa, Qt, niri, Quickshell… esperan estos días tras publicarse (sin IA, 7). Los parches de seguridad no esperan"
            key: "mamori.maturationDays"
            from: 0; to: 14; stepSize: 1
            format: v => Math.round(v) === 0 ? "sin espera" : Math.round(v) + (Math.round(v) === 1 ? " día" : " días")
        }
        ToggleRow {
            title: "Paquetes del AUR"
            sub: "Solo con el PKGBUILD revisado; los compila root en un entorno aislado sin acceso a tu carpeta"
            key: "mamori.aur"
        }
        DropRow {
            title: "Firmware de BIOS/UEFI"
            sub: "El resto de dispositivos se prepara solo; la BIOS siempre espera tu aprobación con un toque"
            key: "mamori.firmware"
            options: [{ id: "approve", label: "Preguntarme" }, { id: "off", label: "No avisar" }]
        }
        ToggleRow {
            title: "Reinicio nocturno"
            sub: "Si una actualización lo necesita, reinicia de madrugada con la sesión bloqueada y el cargador puesto (guarda tus ventanas)"
            key: "mamori.nightlyReboot"
        }
        ToggleRow {
            title: "Mejoras automáticas"
            sub: "Apagado: la IA solo arregla compatibilidad y deja las mejoras como propuestas en docs/mantenimiento/propuestas.md"
            key: "mamori.autoImprove"
        }
        ToggleRow {
            title: "Notificaciones"
            sub: "Solo cuando hay algo que ver; un resumen discreto el domingo. Las críticas llegan siempre"
            key: "mamori.notify"
        }
    }

    SectionTitle { text: "控 Copias" }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 10
        rowSpacing: 10
        StatTile {
            icon: "photo_library"
            value: page.h.hikaeCount != null ? String(page.h.hikaeCount) : "—"
            label: "Fotos de tu carpeta personal"
        }
        StatTile {
            icon: "schedule"
            value: page.h.hikaeLast ? Mamori.stamp(page.h.hikaeLast) : "—"
            label: "La más reciente · cada hora"
        }
        StatTile {
            icon: "verified_user"
            value: page.h.hikaeLast && Mamori.now - page.h.hikaeLast * 1000 < 2 * 86400000 ? "Al día" : "Revisar"
            label: "Mismo SSD: protege de borrados, no de un robo"
        }
    }
    RowLayout {
        Layout.topMargin: 12
        spacing: 10
        OButton {
            icon: "add_a_photo"
            text: "Hacer una copia ahora"
            onClicked: {
                Quickshell.execDetached([Paths.bin + "/ocarina-backup", "now"]);
                Osd.show("info", 0, "控 Copia de tu carpeta en marcha", "add_a_photo");
            }
        }
        OButton {
            ghost: true
            visible: Tools.has("ghostty")
            icon: "restore_page"
            text: "Recuperar un fichero"
            onClicked: Quickshell.execDetached(["ghostty", "+new-window", "--title=控 Recuperar", "-e", "fish", "-C",
                "echo '控 Hikae · ocarina backup list <ruta> · ocarina backup restore <ruta> (va a ~/Restaurado/)'"])
        }
    }
}
