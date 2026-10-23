pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 鬼 Oni / Juegos (phase 11 A, D-060): what the performance mode changes (services/Modes.qml applies it; leaving puts
// everything back), when it starts by itself (GameMode), and how to launch games (gamescope templates, MangoHud).
SetteiPage {
    id: page
    subtitle: "Rendimiento extremo para juegos y trabajo pesado: todo el equipo mientras haga falta, y vuelta exacta al salir."
    resetPaths: ["oni"]
    readonly property var o: Settings.data.oni
    readonly property var st: PowerCtl.status
    readonly property bool fanReady: st.fan?.control === true
    readonly property bool scxReady: st.scxAvailable === true

    SectionTitle { text: "Estado" }
    Card {
        SRow {
            title: Modes.oni ? "Oni está activo" : "Oni está apagado"
            sub: Modes.oni ? "Desde " + Qt.formatTime(new Date(Modes.prev?.at ?? Date.now()), "HH:mm")
                    + (Modes.prev?.auto ? " · con un juego (GameMode)" : "")
                    + " · al salir vuelve todo como estaba"
                : Modes.shinobi ? "Ahora estás en Shinobi: entrar en Oni lo apaga primero"
                : "Mod+Alt+O, el mosaico de Engawa u «ocarina oni» · solo al abrir un juego si está en automático"
            OButton {
                text: Modes.oni ? "Salir de Oni" : "Entrar en Oni"
                primary: !Modes.oni
                enabled: !Modes.busy
                onClicked: Modes.oniToggle("manual")
            }
        }
    }

    SectionTitle { text: "Disparadores" }
    Card {
        ToggleRow { title: "Automático con juegos"; sub: "GameMode lo enciende al abrir un juego y lo apaga al cerrar el último"; key: "oni.auto" }
        DropRow {
            title: "Con batería"
            sub: "Qué hace el automático desenchufado (a mano siempre puedes)"
            key: "oni.batteryAuto"
            options: [{ id: "ask", label: "Preguntar" }, { id: "never", label: "No activarlo" }, { id: "allow", label: "Activarlo" }]
        }
        SliderRow {
            title: "Salir con la batería por debajo de"
            key: "oni.exitBatteryAt"
            from: 10; to: 50; stepSize: 5
            format: v => Math.round(v) + " %"
        }
    }

    SectionTitle { text: "Equipo" }
    Card {
        ToggleRow {
            title: "Planificador scx_lavd (modo juego)"
            sub: page.scxReady ? "Prioriza lo que mueve los fotogramas: +8–10 % medido con CPU y GPU a la vez"
                : "Necesita scx-scheds y el ayudante de energía"
            key: "oni.scx"
            dimmed: !page.scxReady || !PowerCtl.available
        }
        DropRow {
            title: "GPU"
            sub: "«Alta» fija el reloj al máximo: en la 860M no midió más fps que «Automática»"
            key: "oni.gpuLevel"
            options: [{ id: "auto", label: "Automática" }, { id: "high", label: "Alta" }]
            dimmed: !PowerCtl.available
        }
        ToggleRow {
            title: "Prioridad a la GPU"
            sub: "Sin turbo de CPU: la potencia compartida va a la gráfica (+9 % si el juego depende de la GPU, peor si depende de la CPU)"
            key: "oni.gpuFirst"
            dimmed: !PowerCtl.available
        }
        ToggleRow { title: "Wi-Fi sin ahorro"; sub: "Menos latencia en juegos en línea"; key: "oni.wifiNoPs"; dimmed: !PowerCtl.available }
        ToggleRow {
            title: "Ventilador al máximo"
            sub: page.fanReady ? "Solo con el cargador · vuelve a automático al salir (el firmware sigue protegiendo)"
                : "Necesita thinkpad_acpi con control del ventilador: sudo bash scripts/root/fase-11.sh y reiniciar"
            key: "oni.fanMax"
            dimmed: !page.fanReady
        }
        SRow {
            title: "鬼神 Kishin"
            sub: "Límites de potencia por encima de los de Lenovo: desactivado por decisión (D-060), siempre los de fábrica"
            dimmed: true
            Chip { text: "no" }
        }
    }

    SectionTitle { text: "Pantalla y escritorio" }
    Card {
        ToggleRow { title: "VRR en juegos"; sub: "gamescope y juegos de Steam/Proton: el panel sigue los fps (48–120 Hz)"; key: "oni.vrrGames" }
        ToggleRow { title: "Luz nocturna en pausa"; sub: "Colores reales mientras dura"; key: "oni.nightLightPause" }
        ToggleRow { title: "No molestar mientras dura"; sub: "Solo pasan los avisos críticos"; key: "oni.dnd" }
        ToggleRow { title: "Pausar Windows (Fune)"; sub: "La máquina virtual se pausa si no hay apps de Windows abiertas"; key: "oni.funePause" }
        SRow {
            title: "Servicios en pausa"
            sub: (page.o.pauseServices ?? []).length > 0 ? page.o.pauseServices.join(" · ")
                : "Ninguno · unidades de usuario en settings.json → oni.pauseServices"
        }
    }

    SectionTitle { text: "Juegos" }
    Card {
        DropRow {
            title: "Plantilla de gamescope"
            sub: "Para «ocarina play» y las opciones de Steam"
            key: "oni.gamescopePreset"
            menuWidth: 300
            options: [{ id: "fsr", label: "Mitad + FSR (más fps, nítido)" }, { id: "1200", label: "1920×1200 + FSR" },
                      { id: "native", label: "Resolución nativa" }, { id: "off", label: "Sin gamescope" }]
        }
        SRow {
            id: steamRow
            title: "Opciones de lanzamiento de Steam"
            sub: steamOpts.out
            OButton {
                text: steamRow.copied ? "Copiado" : "Copiar"
                enabled: steamOpts.out !== ""
                onClicked: {
                    Quickshell.execDetached(["wl-copy", "--", steamOpts.out]);
                    steamRow.copied = true;
                    copiedReset.restart();
                }
            }
            property bool copied: false
            Timer {
                id: copiedReset
                interval: 2000
                onTriggered: steamRow.copied = false
            }
        }
        SRow {
            title: "MangoHud"
            sub: "Mayús dcha + F12 lo muestra u oculta · Mayús izda + F2 registra 60 s en ~/.local/state/ocarinashell/mangohud"
        }
        SRow {
            title: "Desde la terminal"
            sub: "ocarina play <juego> · ocarina play --preset native <juego> · ntsync activo para Wine/Proton"
        }
    }

    SectionTitle { text: "Siempre en Oni" }
    Card {
        SRow { title: "Perfil rendimiento"; sub: "El de Lenovo sube el límite de potencia (24 → 30 W medidos) · turbo y EPP al máximo"; Chip { text: "fijo" } }
        SRow { title: "Pantalla a su máximo de Hz"; sub: "Y la shell sin animaciones, desenfoque, tiempo ni segundos"; Chip { text: "fijo" } }
        SRow { title: "Guardias"; sub: "Tctl ≥ 97 °C durante 10 s o batería baja → sale solo y avisa"; Chip { text: "fijo" } }
    }

    // the Steam string comes from the CLI (one source of truth with `ocarina play`; sizes from the panel)
    Process {
        id: steamProc
        command: ["ocarina", "play", "--steam", page.o.gamescopePreset ?? "fsr"]
        stdout: StdioCollector {
            id: steamOpts
            readonly property string out: text.trim()
        }
        function refresh(): void {
            if (!page.visible)
                return;
            running = false;
            running = true;
        }
        onCommandChanged: refresh()
        Component.onCompleted: refresh()
    }
    onVisibleChanged: steamProc.refresh()
}
