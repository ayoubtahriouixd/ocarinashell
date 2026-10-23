pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 窓 Ventanas y reglas: niri layout (gaps, focus ring, default width, animations) via overrides.kdl + 窓 Mado rules.
SetteiPage {
    id: page
    subtitle: "Huecos, anillo de foco, ancho de las ventanas nuevas y animaciones de niri. Y tus reglas de Mado."
    resetPaths: ["windows"]
    property int rules: 0
    FileView {
        path: Paths.state + "/niri/user-rules.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.rules = (text().match(/^\/\/ mado: /mg) ?? []).length
        onLoadFailed: page.rules = 0
    }

    SectionTitle { text: "Disposición" }
    Card {
        SliderRow { title: "Huecos entre ventanas"; key: "windows.gaps"; from: 0; to: 32; stepSize: 2; format: v => Math.round(v) + " px" }
        DropRow {
            title: "Ancho de las ventanas nuevas"
            sub: "Las columnas se pueden cambiar luego con Super + − / +"
            key: "windows.defaultWidth"
            options: [{ id: 0.33333, label: "Un tercio" }, { id: 0.5, label: "La mitad" }, { id: 0.66667, label: "Dos tercios" }, { id: 1, label: "Todo el ancho" }]
        }
    }
    SectionTitle { text: "Foco y animaciones" }
    Card {
        ToggleRow { title: "Anillo de foco"; sub: "Borde con el degradado del acento en la ventana activa"; key: "windows.focusRing" }
        SliderRow { title: "Grosor del anillo"; key: "windows.focusRingWidth"; dimmed: !Settings.data.windows.focusRing; from: 1; to: 6; stepSize: 1; format: v => Math.round(v) + " px" }
        ToggleRow {
            title: "Animaciones de niri"
            sub: "Abrir con tinta 墨, cerrar con disolución 溶, desplazamientos · su velocidad sigue a Apariencia"
            key: "windows.niriAnimations"
        }
    }
    SectionTitle { text: "窓 · Reglas de Mado" }
    Card {
        SRow {
            title: "Reglas de ventana"
            sub: page.rules === 0 ? "Ninguna todavía · flotante, ancho, espacio, opacidad, ocultar en capturas…"
                : page.rules === 1 ? "1 regla creada" : page.rules + " reglas creadas"
            OButton {
                icon: "tune"
                text: "Abrir Mado"
                onClicked: Panels.toggle("mado", "")
            }
        }
    }
    OText {
        visible: NiriConf.error !== ""
        Layout.topMargin: 10
        text: "niri no aceptó el cambio: " + NiriConf.error
        color: Theme.colors.error
        size: 12.5
        wrapMode: Text.WordWrap
    }
}
