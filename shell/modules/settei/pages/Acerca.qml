pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 情報 Acerca de: animated logo hero, versions, hardware, diagnostics (modules not available and why), credits and
// licences and terms of use (docs/LICENCIA.md). Versions and hardware are read once when the page opens.
SetteiPage {
    id: page
    subtitle: "Versiones, tu equipo, el estado de cada módulo, créditos y condiciones de uso."
    resetPaths: []
    property var info: ({})
    Process {
        running: true
        command: ["sh", "-c",
            "printf 'qs=%s\\n' \"$(qs --version 2>/dev/null | head -1)\"; "
            + "printf 'niri=%s\\n' \"$(niri --version 2>/dev/null | head -1)\"; "
            + "printf 'qt=%s\\n' \"$(qmake6 -query QT_VERSION 2>/dev/null || pacman -Q qt6-base 2>/dev/null | cut -d' ' -f2)\"; "
            + "printf 'vram=%s\\n' \"$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | sort -n | tail -1)\"; "
            + "printf 'kernel=%s\\n' \"$(uname -r)\"; "
            + "printf 'cpu=%s\\n' \"$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\"; "
            + "printf 'gpu=%s\\n' \"$(lspci -mm 2>/dev/null | grep -Ei 'vga|display' | head -1 | cut -d'\"' -f6)\"; "
            + "printf 'ram=%s\\n' \"$(awk '/MemTotal/ {printf \"%.0f\", $2/1048576}' /proc/meminfo)\"; "
            + "printf 'model=%s\\n' \"$(cat /sys/class/dmi/id/product_version 2>/dev/null)\"; "
            + "printf 'os=%s\\n' \"$(. /etc/os-release && echo \"$PRETTY_NAME\")\""]
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("=");
                if (i > 0) {
                    const o = Object.assign({}, page.info);
                    o[line.slice(0, i)] = line.slice(i + 1).trim();
                    page.info = o;
                }
            }
        }
    }
    readonly property var failures: Object.keys(Health.failures).map(k => ({ name: k, why: Health.failures[k] }))
    readonly property var missingTools: Tools.probed ? Tools.names.filter(n => !Tools.has(n)) : []

    // hero
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 230
        radius: Theme.radius.card
        color: Theme.colors.surface1
        border.width: 1
        border.color: Theme.colors.outline
        clip: true
        Kanji {
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.verticalCenter: parent.verticalCenter
            visible: Settings.data.appearance.kanjiDecor
            text: "殻"
            size: 150
            opacity: 0.05
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 34
            anchors.rightMargin: 34
            spacing: 30
            OcarinaLogo {
                Layout.preferredWidth: 170
                Layout.preferredHeight: 170
                animated: Motion.enabled
                loops: false
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    text: "Ocarina<font color=\"" + Theme.colors.accent + "\">Shell</font>"
                    color: Theme.colors.text
                    font.family: Theme.font.brand
                    font.weight: Font.DemiBold
                    font.pointSize: 34 * 0.75 * Theme.font.scale
                }
                OText { Layout.fillWidth: true; text: "オカリナシェル · tu escritorio, sobre niri y Quickshell"; font.family: Theme.font.jp; size: 15; color: Theme.colors.textMuted }
                OText { Layout.fillWidth: true; text: "Created by Ayoub"; size: 13; font.weight: Font.Medium; color: Theme.colors.text }
                RowLayout {
                    spacing: 8
                    Layout.topMargin: 6
                    Chip { kanji: "版"; text: "versión " + Paths.version; tone: "red" }
                    Chip { kanji: Theme.kanji; text: "tema " + Theme.name }
                }
            }
        }
    }

    SectionTitle { text: "Versiones" }
    Card {
        SRow { title: "OcarinaShell"; minHeight: 44; OText { text: Paths.version; tabular: true; color: Theme.colors.textMuted } }
        SRow { title: "Quickshell"; minHeight: 44; OText { text: (page.info.qs ?? "…").replace(/^Quickshell /, "").replace(/ \(revision.*$/, ""); color: Theme.colors.textMuted } }
        SRow { title: "Qt"; minHeight: 44; OText { text: page.info.qt ?? "…"; tabular: true; color: Theme.colors.textMuted } }
        SRow { title: "niri"; minHeight: 44; OText { text: (page.info.niri ?? "…").replace(/^niri /, ""); color: Theme.colors.textMuted } }
        SRow { title: "Núcleo"; minHeight: 44; OText { text: page.info.kernel ?? "…"; tabular: true; color: Theme.colors.textMuted } }
        SRow { title: "Sistema"; minHeight: 44; OText { text: page.info.os ?? "…"; color: Theme.colors.textMuted } }
    }

    SectionTitle { text: "Equipo" }
    Card {
        SRow { title: "Modelo"; minHeight: 44; OText { text: page.info.model ?? "…"; color: Theme.colors.textMuted } }
        SRow { title: "Procesador"; minHeight: 44; OText { text: page.info.cpu ?? "…"; color: Theme.colors.textMuted } }
        // lspci says «Krackan [Radeon 840M / 860M Graphics]»: the marketing name in brackets reads better
        SRow { title: "Gráfica"; minHeight: 44; OText {
            // the PCI name covers two chips («840M / 860M»); an APU's CPU string names the one it has
            text: /w\/ (Radeon \S+)/.test(page.info.cpu ?? "") ? "AMD " + /w\/ (Radeon \S+)/.exec(page.info.cpu)[1]
                : (page.info.gpu || "—").replace(/^.*\[(.*)\]\s*$/, "AMD $1").replace(/ Graphics$/, "")
            color: Theme.colors.textMuted
        } }
        SRow { title: "Memoria"; minHeight: 44; OText {
            text: (page.info.ram ?? "…") + " GB" + (Number(page.info.vram) > 0
                ? " + " + Math.round(Number(page.info.vram) / 1073741824) + " GB reservados para la gráfica (UMA)" : "")
            tabular: true
            color: Theme.colors.textMuted
        } }
        SRow {
            title: "Pantallas"
            minHeight: 44
            OText {
                text: Object.keys(Niri.outputs).map(k => {
                    const o = Niri.outputs[k], m = (o.modes ?? [])[o.current_mode ?? -1];
                    return k + (m ? " · " + m.width + "×" + m.height + " · " + Math.round(m.refresh_rate / 1000) + " Hz" : "");
                }).join("   ")
                color: Theme.colors.textMuted
                tabular: true
            }
        }
    }

    SectionTitle { text: "Diagnóstico" }
    Card {
        SRow {
            title: page.failures.length === 0 ? "Todos los módulos funcionan" : page.failures.length + " módulo(s) no disponibles"
            sub: page.failures.length === 0 ? "Sin errores desde el arranque de la shell" : "El resto de la shell sigue funcionando"
            leadIcon: page.failures.length === 0 ? "check_circle" : "error"
            OButton {
                icon: "content_copy"
                text: "Copiar informe"
                onClicked: Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", Health.report()])
            }
        }
        Repeater {
            model: page.failures
            delegate: SRow {
                required property var modelData
                title: modelData.name
                sub: String(modelData.why).slice(0, 160)
                leadIcon: "warning"
            }
        }
        SRow {
            visible: page.missingTools.length > 0
            title: "Herramientas que faltan"
            sub: page.missingTools.join(" · ") + " · lo que depende de ellas se oculta solo"
            leadIcon: "build"
        }
    }

    SectionTitle { text: "Licencia y condiciones de uso" }
    Card {
        SRow {
            title: "Created by Ayoub"
            sub: "© 2026 Ayoub · OcarinaShell (オカリナシェル)"
            leadIcon: "person"
            OButton {
                icon: "description"
                text: "Condiciones completas"
                onClicked: Quickshell.execDetached(["xdg-open", Paths.repo + "/docs/LICENCIA.md"])
            }
        }
        SRow { title: "Código · GPL-3.0 o posterior"; sub: "Úsalo, estúdialo, cámbialo y compártelo; si distribuyes una versión, con su código y la misma licencia"; leadIcon: "code" }
        SRow { title: "Arte · CC BY-SA 4.0"; sub: "Fondos, sonidos, mockups y temas de arranque: reutilizables citando «OcarinaShell · Ayoub»"; leadIcon: "palette" }
        SRow { title: "Nombre y logo"; sub: "Identifican el proyecto original: un fork lleva otro nombre y otro logo"; leadIcon: "verified" }
        SRow { title: "Sin garantía"; sub: "Se ofrece tal cual. Toca el arranque y el sistema, siempre con snapshot previo y rescate: úsalo bajo tu responsabilidad"; leadIcon: "gpp_maybe" }
        SRow { title: "Privacidad"; sub: "Sin telemetría · Snake y la voz, en local (el audio solo en RAM) · red solo para el tiempo, actualizaciones, noticias de Mamori, modelos y Wallhaven si lo activas"; leadIcon: "shield" }
    }

    SectionTitle { text: "Créditos" }
    Card {
        SRow { title: "Código de OcarinaShell"; sub: "Escrito desde cero, sin copiar otras shells · arte, logo, fondos y sonidos originales"; leadIcon: "code" }
        SRow { title: "Tipografías"; sub: "Geist, Unbounded, Zen Kaku Gothic New, Shippori Mincho B1, Yuji Syuku, JetBrains Mono (SIL OFL 1.1) · Material Symbols (Apache 2.0)"; leadIcon: "text_fields" }
        SRow { title: "Sobre los hombros de"; sub: "niri (GPL-3.0) · Quickshell (LGPL-3.0) · Qt (LGPL-3.0) · matugen · ddcutil · cliphist · whisper.cpp y llama.cpp (MIT)"; leadIcon: "favorite" }
        SRow { title: "Datos"; sub: "七十二候 y 伝統色 de dominio público · tiempo de Open-Meteo (CC BY 4.0)"; leadIcon: "dataset" }
    }
}
