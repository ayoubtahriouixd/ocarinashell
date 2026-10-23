pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 船 Windows (Fune, phase 12, D-062): the VM's state and buttons, automatic pause/stop, start on AC, the detected
// apps, resources, what Windows can see, and Mamori's maintenance (update, backup). The panel is the live view;
// this page keeps the defaults.
SetteiPage {
    id: page
    subtitle: "Apps de Windows como ventanas normales: web, Wine/Proton o una máquina virtual que se pausa sola."
    resetPaths: ["fune"]
    readonly property var f: Settings.data.fune

    SectionTitle { text: "Estado" }
    Card {
        SRow {
            title: Fune.label
            sub: !Fune.available ? Fune.unavailableReason
                : !Fune.installed ? "Instálalo con «ocarina fune create» (descarga Windows 11 y lo instala sin intervención)"
                : Fune.installing ? "Windows se está instalando: puedes seguirlo en http://127.0.0.1:8006"
                : Fune.paused ? "0 % de CPU · la RAM se conserva para volver en un segundo"
                : Fune.running ? Fune.windows + (Fune.windows === 1 ? " app abierta" : " apps abiertas") + " · RDP 127.0.0.1:3389"
                : "Apagada · no gasta RAM ni CPU"
            OButton {
                visible: Fune.installed && Fune.available
                enabled: !Fune.busy && !Fune.stopping
                text: Fune.running ? "Pausar" : Fune.paused ? "Reanudar" : "Arrancar"
                onClicked: Fune.running ? Fune.pause() : Fune.paused ? Fune.resume() : Fune.start()
            }
            OButton {
                visible: Fune.installed && Fune.on
                enabled: !Fune.busy && !Fune.stopping
                text: Fune.stopping || Fune.busyAction === "stop" ? "Apagando…" : "Apagar"
                onClicked: Fune.stop()
            }
        }
        SRow {
            title: "Escritorio de Windows"
            sub: "El escritorio completo en una ventana: para instalar programas o cambiar ajustes de Windows"
            dimmed: !Fune.installed || Fune.installing
            OButton {
                text: "Abrir"
                enabled: Fune.installed && !Fune.installing && !Fune.stopping
                onClicked: Fune.desktop()
            }
        }
    }

    SectionTitle { text: "Ahorro" }
    Card {
        ToggleRow {
            title: "Pausa automática"
            sub: "Sin apps de Windows abiertas → pausa: 0 % de CPU, abrir una app tarda ~1 s"
            key: "fune.autoPause"
        }
        SliderRow {
            title: "Pausar tras"
            key: "fune.pauseMinutes"
            from: 1; to: 60; stepSize: 1
            format: v => Math.round(v) + " min"
        }
        SliderRow {
            title: "Apagar tras estar en pausa"
            sub: "Libera la RAM; la siguiente app tarda lo que un arranque (~30 s)"
            key: "fune.stopMinutes"
            from: 0; to: 240; stepSize: 5
            format: v => v <= 0 ? "nunca" : Math.round(v) + " min"
        }
        ToggleRow {
            title: "Arrancar con el cargador"
            sub: "Al iniciar sesión enchufado, Windows arranca y se queda en pausa lista al instante"
            key: "fune.startOnAC"
        }
        ToggleRow {
            title: "Micrófono para Windows"
            sub: "Las apps de Windows pueden usarlo mientras están abiertas (Obi lo indica como cualquier otra)"
            key: "fune.microphone"
        }
        SRow {
            title: "忍 Shinobi y 鬼 Oni"
            sub: "Shinobi pausa al momento y apaga tras 5 min; Oni pausa si no hay apps de Windows abiertas"
            OButton {
                text: "Ver"
                onClicked: Settei.go("shinobi")
            }
        }
    }

    SectionTitle { text: "Apps de Windows" }
    Card {
        SRow {
            title: Fune.apps.length + (Fune.apps.length === 1 ? " app detectada" : " apps detectadas")
            sub: "Aparecen en Torii con el sello 船 y en «Abrir con» de Nautilus"
            OButton {
                text: Fune.busyAction === "scan" ? "Buscando…" : "Buscar en Windows"
                enabled: Fune.installed && !Fune.installing && !Fune.busy
                onClicked: Fune.scan()
            }
        }
        Repeater {
            model: Fune.apps
            delegate: SRow {
                required property var modelData
                title: modelData.name
                sub: modelData.exe
                OButton {
                    text: "Abrir"
                    ghost: true
                    onClicked: Fune.launch(modelData.id)
                }
                OButton {
                    text: "Quitar"
                    ghost: true
                    onClicked: Fune.forget(modelData.id)
                }
            }
        }
        SRow {
            title: "Apps web y Wine/Proton"
            sub: Fune.webCount + " web · " + Fune.wineCount + " con Wine · «ocarina fune webapp» y «ocarina fune wine» (o «Añadir app» en el panel)"
        }
    }

    SectionTitle { text: "Máquina virtual" }
    Card {
        SRow {
            title: "Windows " + (Fune.vm.version === "11" ? "11 Pro" : Fune.vm.version) + " · " + Fune.cores + " vCPU · "
                   + Math.round(Fune.memMax / 1073741824) + " GB · disco de " + Math.round(Fune.diskMax / 1073741824) + " GB"
            sub: "Se cambia en config/winapps/compose.yaml con Windows apagada · disco NOCOW fuera de los snapshots"
        }
        SRow {
            title: "Qué ve Windows"
            sub: "Tu carpeta personal (\\\\tsclient\\home) y los USB, solo mientras hay una app abierta"
        }
        SRow {
            title: "Seguridad"
            sub: "Podman sin root · puertos solo en 127.0.0.1 · contraseña aleatoria en el llavero, nunca en ficheros"
        }
    }

    SectionTitle { text: "Mantenimiento" }
    Card {
        SRow {
            title: "Actualizar dockur y WinApps"
            sub: "Con Windows apagada; el disco de Windows se conserva tal cual"
            OButton {
                text: "Actualizar"
                enabled: !Fune.busy
                onClicked: Fune.act(["update"])
            }
        }
        SRow {
            title: "Copia del disco de Windows"
            sub: "Copia dispersa (solo lo usado) en ~/.local/share/ocarinashell/fune-backups, con Windows apagada"
            OButton {
                text: "Copiar"
                enabled: !Fune.busy && Fune.off
                onClicked: Fune.act(["backup"])
            }
        }
    }
}
