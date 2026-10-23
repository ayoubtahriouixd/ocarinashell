pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 忍 Shinobi: what the extreme battery mode turns off (services/Modes.qml applies it; leaving puts everything back).
SetteiPage {
    id: page
    subtitle: "Ahorro extremo: todo lo que gasta batería se apaga o se contiene. Elige qué hace."
    resetPaths: ["shinobi"]
    readonly property var sh: Settings.data.shinobi

    SectionTitle { text: "Estado" }
    Card {
        SRow {
            title: Modes.shinobi ? "Shinobi está activo" : "Shinobi está apagado"
            sub: Modes.shinobi ? "Desde " + Qt.formatTime(new Date(Modes.prev?.at ?? Date.now()), "HH:mm")
                    + (Modes.lastReason !== "" && Modes.lastReason !== "manual" ? " · " + Modes.lastReason : "")
                    + " · al salir vuelve todo como estaba"
                : "Mod+Alt+S, el mosaico de Engawa u «ocarina shinobi» · se activa solo según Energía"
            OButton {
                text: Modes.shinobi ? "Salir de Shinobi" : "Entrar en Shinobi"
                primary: !Modes.shinobi
                enabled: !Modes.busy
                onClicked: Modes.toggle("manual")
            }
        }
    }

    SectionTitle { text: "Pantalla" }
    Card {
        ToggleRow { title: "Frecuencia variable (VRR)"; sub: "El panel baja solo hasta 30 Hz con la imagen quieta: −1 W y sin parpadeo al entrar"; key: "shinobi.vrr" }
        ToggleRow { title: "Bajar a 60 Hz"; sub: "Ahorra menos que VRR (−0,5 W) y la pantalla parpadea al cambiar de modo; se suma a VRR si los dos están activos"; key: "shinobi.refresh60" }
        SliderRow { title: "Brillo máximo de la interna"; key: "shinobi.brightnessCap"; from: 10; to: 100; stepSize: 5; format: v => Math.round(v) + " %" }
        SliderRow {
            title: "Brillo máximo de los monitores"
            sub: "Pensado para monitores USB-C que se alimentan del portátil"
            key: "shinobi.brightnessCapExternal"
            from: 10; to: 100; stepSize: 5
            format: v => v >= 100 ? "sin tope" : Math.round(v) + " %"
        }
        ToggleRow { title: "Apagar la luz del teclado"; key: "shinobi.kbdLightOff" }
    }
    SectionTitle { text: "Equipo" }
    Card {
        ToggleRow {
            title: "Sin turbo de CPU"
            sub: PowerCtl.available ? "Frecuencia base: menos calor y ventilador" : "Necesita el ayudante de energía: sudo bash scripts/install-system.sh"
            key: "shinobi.boostOff"
        }
        ToggleRow {
            title: "GPU al mínimo"
            sub: "Fuerza el nivel más bajo de la Radeon (−0,2 W medidos) · apágalo si un vídeo va a saltos"
            key: "shinobi.gpuLow"
            dimmed: !PowerCtl.available
        }
        ToggleRow { title: "Wi-Fi en ahorro"; key: "shinobi.wifiPowersave"; dimmed: !PowerCtl.available }
        ToggleRow { title: "Apagar el Bluetooth"; key: "shinobi.bluetoothOff" }
        ToggleRow {
            title: "Mantenerlo si hay audio conectado"
            sub: "Cascos o altavoz: el Bluetooth sigue encendido"
            key: "shinobi.bluetoothKeepAudio"
            dimmed: !page.sh.bluetoothOff
        }
        ToggleRow { title: "Pausar y apagar Windows (Fune)"; sub: "Sin apps de Windows: pausa al momento y apaga tras 5 min"; key: "shinobi.funeStop" }
        SRow {
            title: "Servicios en pausa"
            sub: (page.sh.pauseServices ?? []).length > 0 ? page.sh.pauseServices.join(" · ")
                : "Ninguno · unidades de usuario en settings.json → shinobi.pauseServices"
        }
    }
    SectionTitle { text: "Siempre en Shinobi" }
    Card {
        SRow { title: "Sin animaciones, sin desenfoque ni transparencias"; sub: "Y sin ecualizador, tiempo, segundos, sonidos ni sondeos"; Chip { text: "fijo" } }
        SRow { title: "Tema Shinobi y fondo negro"; sub: "Negro puro OLED; tu tema vuelve al salir"; Chip { text: "fijo" } }
        SRow { title: "Perfil de ahorro"; sub: "power-profiles-daemon en «ahorro» (también quita el turbo en AMD)"; Chip { text: "fijo" } }
    }
}
