pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 滑 Nameraka · vídeo fluido (phase 11 B, D-061; docs/02-DISENO «Settei → 滑 Nameraka»): default mode and target,
// engine, quality and calibration, battery policy, audio sync, automatic start, excluded apps, and the state of
// lsfg-vk and of the Lossless Scaling DLL with how to install them. Engawa's page is the live view; this one keeps
// the defaults.
SetteiPage {
    id: page
    subtitle: "Genera fotogramas en cualquier vídeo a pantalla completa (Lossless Scaling): hasta los Hz de tu pantalla."
    resetPaths: ["nameraka"]
    readonly property var n: Settings.data.nameraka
    readonly property var st: Nameraka.selftest
    readonly property var stages: st.stages ?? ({})

    SectionTitle { text: "Estado" }
    Card {
        SRow {
            title: !Nameraka.tested ? "Comprobando…" : Nameraka.available ? "Listo" : "No disponible"
            sub: Nameraka.available ? (Nameraka.on ? Nameraka.subtitle : "Mod+Alt+F o la tarjeta 滑 de Engawa sobre un vídeo a pantalla completa")
                : Nameraka.unavailableReason
            OButton {
                text: Nameraka.wanted ? "Apagar" : "Encender"
                primary: !Nameraka.wanted
                enabled: Nameraka.available && !Nameraka.blocked && (!Nameraka.batteryOff || Nameraka.wanted)
                onClicked: Nameraka.toggle()
            }
        }
        SRow {
            title: "lsfg-vk"
            sub: page.stages.lsfgvk ? "Instalado (capa Vulkan 2.0 de los repos de CachyOS)" : "Falta: sudo pacman -S lsfg-vk"
            Chip { text: page.stages.lsfgvk ? "ok" : "falta"; tone: page.stages.lsfgvk ? "ok" : "red" }
        }
        SRow {
            title: "Lossless Scaling (Steam)"
            sub: page.stages.dll ? (page.st.dll ?? "") : "Instálalo en Steam y elige la beta «lsfg-vk» (Propiedades → Betas)"
            Chip { text: page.stages.dll ? "rama lsfg-vk" : "falta"; tone: page.stages.dll ? "ok" : "red" }
        }
        SRow {
            title: "Captura de niri, capa y Vulkan"
            sub: page.stages.screencast && page.stages.layerShell && page.stages.vulkan
                ? "ScreenCast v4 · layer-shell · DMA-BUF con " + (page.stages.modifiers ?? 0) + " modificadores"
                : "Algo falla: ocarina nameraka self-test"
            OButton {
                text: "Comprobar"
                onClicked: Quickshell.execDetached(["sh", "-c", "systemctl --user start ocarina-nameraka-selftest.service"])
            }
        }
    }

    SectionTitle { text: "Por defecto" }
    Card {
        DropRow {
            title: "Modo"
            sub: "«A medida» llena los Hz de la pantalla: casi siempre el mejor"
            key: "nameraka.mode"
            options: [{ id: "custom", label: "A medida" }, { id: "x2", label: "×2" }, { id: "x4", label: "×4" }, { id: "x6", label: "×6" }]
        }
        SliderRow {
            title: "Objetivo de «A medida»"
            key: "nameraka.fps"
            from: 0; to: 120; stepSize: 10
            format: v => v <= 0 ? "los Hz" : Math.round(v) + " fps"
        }
        DropRow {
            title: "Con batería"
            key: "nameraka.battery"
            options: [{ id: "eco", label: "Económico" }, { id: "normal", label: "Normal" }, { id: "off", label: "Apagado" }]
        }
        ToggleRow { title: "Sincronizar audio"; sub: "Retrasa el sonido de esa app lo mismo que la imagen (≈ 45–65 ms)"; key: "nameraka.avSync" }
        ToggleRow { title: "Automático"; sub: "Arranca solo cuando un vídeo que suena pasa a pantalla completa"; key: "nameraka.auto" }
    }

    SectionTitle { text: "Motor y calidad" }
    Card {
        SRow {
            title: "Motor"
            sub: "LSFG 3.1 (Lossless Scaling). IA: " + (page.st.engines?.iaReason ?? "no disponible")
            Chip { text: "LSFG 3.1" }
        }
        SliderRow {
            title: "Resolución del flujo"
            sub: page.n.flow > 0 ? "Fijada a mano" : "Automática según la calibración"
            key: "nameraka.flow"
            from: 0; to: 1; stepSize: 0.05
            format: v => v <= 0 ? "auto" : Math.round(v * 100) + " %"
        }
        DropRow {
            title: "Modo rendimiento"
            key: "nameraka.perf"
            options: [{ id: "auto", label: "Automático" }, { id: "on", label: "Siempre" }, { id: "off", label: "Nunca" }]
        }
        SRow {
            title: "Calibración"
            sub: "Mide lo que aguanta la GPU con cada multiplicador y calidad (≈ 1 min, con Nameraka apagado)"
            OButton {
                text: "Calibrar"
                enabled: !Nameraka.wanted
                onClicked: Nameraka.calibrate()
            }
        }
    }

    SectionTitle { text: "Exclusiones" }
    Card {
        SRow {
            title: "Apps excluidas"
            sub: (page.n.exclude ?? []).length > 0 ? page.n.exclude.join(" · ")
                : "Ninguna · gamescope y los juegos de Steam siempre lo están (usa lsfg-vk directo, en Oni)"
        }
    }
}
