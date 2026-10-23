pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.fune

// 船 Fune — Windows apps panel (mockup 09, docs/02-DISENO §5 «Fune»): right 10 · top 56 · 420 wide · radius 22.
// Hanko header, status card (dot, uptime, apps, automatic-pause chip, vCPU/RAM/disk bars only while open, Pausar ·
// Escritorio · Apagar), 3×2 grid of Windows apps + «Añadir app», automatic pause / start on AC, shared folder and
// Wine/Proton in the footer. Opened from the 船 indicator of Obi and Mod+Alt+W.
PanelSurface {
    id: root
    implicitWidth: 420
    implicitHeight: col.implicitHeight + 32

    property bool adding: false
    property bool webHint: false
    property real now: Date.now()
    readonly property int cfgPause: Settings.data.fune.pauseMinutes ?? 10
    readonly property bool noStats: !Fune.running || !Fune.statsFresh || Modes.shinobi

    Component.onCompleted: Fune.statsUsers++
    Component.onDestruction: Fune.statsUsers = Math.max(0, Fune.statsUsers - 1)
    Timer {                                // uptime with minute precision, only while the panel is open
        interval: 30000
        repeat: true
        running: Fune.on
        onTriggered: root.now = Date.now()
    }

    function uptime(): string {
        if (Fune.since <= 0)
            return "";
        const m = Math.max(0, Math.floor((root.now - Fune.since) / 60000));
        return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min";
    }
    function gib(b: real): string {
        return Math.round(b / 1073741824);
    }

    ColumnLayout {
        id: col
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 0

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 11
            Rectangle {
                implicitWidth: 38
                implicitHeight: 38
                radius: Theme.radius.control + 1
                color: Theme.colors.asagi
                border.width: 1.5                        // .hanko: inset 0 0 0 1.5px rgba(255,255,255,.22)
                border.color: Theme.alpha(Theme.colors.onImage, 0.22)
                Kanji {
                    anchors.centerIn: parent
                    text: "船"
                    size: 20
                    color: Theme.colors.onImage
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                OText {
                    Layout.fillWidth: true          // a layout only grows if a child can: the gear goes right
                    text: "Fune · apps de Windows"
                    size: Theme.font.title
                    font.weight: Font.DemiBold
                }
                OText {
                    Layout.fillWidth: true
                    text: "Windows · KVM · RemoteApp"
                    size: Theme.font.meta
                    color: Theme.colors.textMuted
                }
            }
            IconButton {
                icon: "settings"
                label: "Ajustes de Windows"
                onClicked: { Panels.close(); Settei.show("fune"); }
            }
        }

        // ── status card ──
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 14
            implicitHeight: status.implicitHeight + 28
            radius: Theme.radius.card
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline

            ColumnLayout {
                id: status
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 11

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item {
                        implicitWidth: 9
                        implicitHeight: 9
                        // the mockup's glow (box-shadow 0 0 10px): a soft static shadow, no shader
                        SoftShadow {
                            visible: Fune.tone === "ok"
                            target: dot
                            color: Theme.alpha(Theme.colors.success, 0.55)
                            blur: 12
                            offsetY: 0
                        }
                        Rectangle {
                            id: dot
                            anchors.fill: parent
                            radius: 5
                            color: Fune.tone === "ok" ? Theme.colors.success : Fune.tone === "warn" ? Theme.colors.warning
                                 : Theme.colors.textDim
                        }
                    }
                    OText {
                        text: Fune.waking ? "Despertando" : Fune.label
                        font.weight: Font.DemiBold
                    }
                    OText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        size: Theme.font.small
                        color: Theme.colors.textMuted
                        text: {
                            if (!Fune.available)
                                return "· " + Fune.unavailableReason;
                            if (Fune.installing)
                                return "· sin intervención, 20–40 min";
                            if (!Fune.on)
                                return Fune.installed ? "· 0 MB de RAM" : "";
                            const parts = [root.uptime()];
                            if (Fune.running)
                                parts.push(Fune.windows + (Fune.windows === 1 ? " app" : " apps"));
                            else if (Fune.paused)
                                parts.push("0 % CPU");
                            return "· " + parts.filter(p => p !== "").join(" · ");
                        }
                    }
                    Chip {
                        visible: Fune.installed && (Settings.data.fune.autoPause || Fune.fastPolicy)
                        text: Fune.fastPolicy ? "pausa auto · " + (Modes.shinobi ? "忍" : "鬼")
                                              : "pausa auto · " + root.cfgPause + " min"
                        tone: "ok"
                    }
                }

                StatBar {
                    label: "vCPU"
                    value: root.noStats ? 0 : Fune.cpu
                    text: Fune.cores + " núcleos · " + (root.noStats ? (Fune.paused ? "0 %" : "—") : Math.round(Fune.cpu * 100) + " %")
                }
                StatBar {
                    label: "RAM"
                    value: root.noStats || Fune.memMax <= 0 ? 0 : Fune.mem / Fune.memMax
                    text: (Fune.on && !root.noStats ? Fune.fmtGB(Fune.mem) : Fune.paused ? "retenida" : "—")
                          + " / " + root.gib(Fune.memMax) + " GB"
                }
                StatBar {
                    label: "Disco"
                    value: Fune.diskMax > 0 ? Fune.disk / Fune.diskMax : 0
                    text: root.gib(Fune.disk) + " / " + root.gib(Fune.diskMax) + " GB"
                }

                RowLayout {
                    Layout.topMargin: 3
                    spacing: 6
                    OButton {
                        visible: Fune.installed
                        enabled: !Fune.busy && !Fune.stopping
                        text: Fune.busyAction === "pause" ? "Pausando…" : Fune.busyAction === "resume" || Fune.busyAction === "start" ? "Arrancando…"
                            : Fune.running ? "Pausar" : Fune.paused ? "Reanudar" : "Arrancar"
                        icon: Fune.running ? "pause" : "play_arrow"
                        onClicked: Fune.running ? Fune.pause() : Fune.paused ? Fune.resume() : Fune.start()
                    }
                    OButton {
                        visible: Fune.installed && !Fune.installing
                        enabled: !Fune.stopping
                        text: "Escritorio"
                        icon: "desktop_windows"
                        onClicked: { Panels.close(); Fune.desktop(); }
                    }
                    OButton {
                        visible: Fune.installed && Fune.on && !Fune.installing
                        enabled: !Fune.busy && !Fune.stopping
                        text: Fune.busyAction === "stop" || Fune.stopping ? "Apagando…" : "Apagar"
                        icon: "power_settings_new"
                        onClicked: Fune.stop()
                    }
                    OButton {
                        visible: Fune.installing
                        text: "Ver la instalación"
                        icon: "open_in_new"
                        onClicked: { Panels.close(); Qt.openUrlExternally("http://127.0.0.1:8006"); }
                    }
                    OButton {
                        visible: Fune.checked && (!Fune.installed || !Fune.available)
                        text: "Cómo instalar"
                        icon: "help"
                        onClicked: { Panels.close(); Settei.show("fune"); }
                    }
                }
            }
        }

        // ── apps ──
        OText {
            Layout.topMargin: 16
            Layout.leftMargin: 2
            Layout.bottomMargin: 8
            Layout.preferredHeight: 11               // font 600 11px/1: the box no taller than the caps
            text: "APPS"
            size: Theme.font.caption - 0.5
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            color: Theme.colors.textDim
        }
        GridLayout {
            Layout.fillWidth: true
            visible: Fune.apps.length > 0
            columns: 3
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                // six tiles; with more apps the sixth becomes «+N» (the full list lives in Ajustes)
                model: Fune.apps.length > 6 ? Fune.apps.slice(0, 5) : Fune.apps
                delegate: AppTile {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    name: modelData.name
                    icon: modelData.icon ?? ""
                    onClicked: { Fune.launch(modelData.id); Panels.close(); }
                }
            }
            AppTile {
                visible: Fune.apps.length > 6
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                name: "+" + (Fune.apps.length - 5) + " más"
                glyph: "apps"
                onClicked: { Panels.close(); Settei.show("fune"); }
            }
        }
        OText {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            visible: Fune.apps.length === 0
            text: !Fune.installed ? "Windows aún no está instalado en esta máquina."
                : Fune.installing ? "Cuando termine la instalación, «Añadir app» busca los programas de Windows."
                : "Aún no hay apps: instala programas en el escritorio de Windows y pulsa «Buscar en Windows»."
            size: Theme.font.small
            color: Theme.colors.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
        DashedButton {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: Fune.installed && Fune.available
            text: root.adding ? "Cerrar" : "Añadir app"
            active: root.adding
            onClicked: root.adding = !root.adding
        }
        // «Añadir app»: the three ways in (docs/historia/fases/fase-12 «Estrategia»)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: root.adding
            spacing: 8
            RowLayout {
                spacing: 6
                OButton {
                    enabled: !Fune.busy && !Fune.installing
                    text: Fune.busyAction === "scan" ? "Buscando…" : "Buscar en Windows"
                    icon: "travel_explore"
                    onClicked: Fune.scan()
                }
                OButton {
                    enabled: !Fune.installing
                    text: "Instalar en el escritorio"
                    icon: "install_desktop"
                    onClicked: { Panels.close(); Fune.desktop(); }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextInput_ {
                    id: webName
                    Layout.preferredWidth: 110
                    placeholder: "Nombre"
                }
                TextInput_ {
                    id: webUrl
                    Layout.fillWidth: true
                    placeholder: "https://… (app web)"
                    onAccepted: addWeb.clicked()
                }
                OButton {
                    id: addWeb
                    enabled: !Fune.busy
                    text: "Web"
                    icon: "public"
                    onClicked: {
                        const u = webUrl.text.trim(), n = webName.text.trim();
                        root.webHint = !/^https?:\/\/\S+\.\S+/.test(u) || n === "";
                        if (root.webHint)
                            return;
                        Fune.webapp(n, u);
                        webUrl.text = "";
                        webName.text = "";
                    }
                }
            }
            OText {
                Layout.fillWidth: true
                text: root.webHint ? "Pon un nombre y una dirección que empiece por https://"
                                   : "Sin máquina virtual (Wine/Proton): ocarina fune wine install <id> <instalador.exe>"
                size: Theme.font.caption
                color: root.webHint ? Theme.colors.error : Theme.colors.textDim
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }

        // ── automatic pause, start on AC ──
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            implicitHeight: toggles.implicitHeight
            radius: Theme.radius.card
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline
            ColumnLayout {
                id: toggles
                width: parent.width
                spacing: 0
                ToggleLine {
                    title: "Pausa automática"
                    sub: "Sin apps abiertas durante " + root.cfgPause + " min · 0 % CPU en pausa"
                    checked: Settings.data.fune.autoPause
                    onToggled: Settings.set("fune.autoPause", !Settings.data.fune.autoPause)
                }
                ToggleLine {
                    separator: true
                    title: "Arrancar con el cargador"
                    sub: "Lista al instante cuando estás enchufado"
                    checked: Settings.data.fune.startOnAC
                    onToggled: Settings.set("fune.startOnAC", !Settings.data.fune.startOnAC)
                }
            }
        }

        // ── footer: shared folder · Wine/Proton ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8
            OIcon {
                icon: "folder_shared"
                size: 18
                color: Theme.colors.textMuted
            }
            OText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "~/ ↔ \\\\tsclient\\home"
                size: Theme.font.meta
                color: Theme.colors.textMuted
            }
            Chip {
                text: "Wine/Proton · " + Fune.wineCount + (Fune.wineCount === 1 ? " app" : " apps")
            }
        }
    }
}
