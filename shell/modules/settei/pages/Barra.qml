pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 帯 Barra e isla: bar style, modules and order, clock, the island's behaviour.
SetteiPage {
    id: page
    subtitle: "Cómo se ve la barra, qué muestra la isla y qué hay en 広場 Hiroba cuando la abres."
    resetPaths: ["bar", "island", "hiroba", "profile"]

    SectionTitle { text: "Barra" }
    Card {
        SRow {
            title: "Estilo"
            sub: Settings.data.bar.style === "minimal" ? "Se esconde sola: acerca el puntero al borde de arriba para verla"
                : Settings.data.bar.style === "attached" ? "De borde a borde, sin esquinas"
                : Settings.data.bar.style === "isles" ? "Transparente: solo dos cápsulas de vidrio y la isla" : "Flotante, con vidrio y esquinas"
            Segmented {
                Layout.preferredWidth: 460
                options: [{ id: "isles", kanji: "島", label: "Islas" }, { id: "floating", kanji: "浮", label: "Flotante" },
                          { id: "attached", kanji: "付", label: "Pegada" }, { id: "minimal", kanji: "隠", label: "Mínima" }]
                current: Settings.data.bar.style
                onPicked: id => Settings.set("bar.style", id)
            }
        }
    }

    SectionTitle { text: "Módulos · arrastra para ordenar" }
    ModulesEditor {}

    SectionTitle { text: "Reloj" }
    Card {
        ToggleRow { title: "Reloj de 24 horas"; sub: Settings.data.bar.clock24 ? "21:38" : "9:38"; key: "bar.clock24" }
        ToggleRow { title: "Mostrar segundos"; sub: "La isla se redibuja cada segundo: gasta un poco más"; key: "bar.showSeconds" }
        ToggleRow { title: "Microestación 七十二候"; sub: "El kanji de la estación junto a la hora"; key: "bar.showKisetsu" }
        ToggleRow { title: "Tiempo"; sub: "Temperatura en la isla y en Koyomi (Open-Meteo, sin clave)"; key: "bar.showWeather" }
        ToggleRow { title: "Uso en tiempo real"; sub: "CPU, RAM y GPU en % junto al perfil de energía (cada 2 s; se para en Shinobi)"; key: "bar.showUsage" }
    }

    SectionTitle { text: "島 · Isla" }
    Card {
        ToggleRow { title: "Música en la isla"; sub: "Portada, título y ecualizador mientras suena algo"; key: "island.media" }
        ToggleRow { title: "Avisos de volumen y brillo"; sub: "La isla crece con la barra del valor (OSD)"; key: "island.osd" }
        ToggleRow { title: "Asomar notificaciones"; sub: "Con No molestar, un resumen de una línea durante 2,5 s"; key: "island.notifPeek" }
        ToggleRow { title: "Indicador de grabación"; sub: "Punto 録 rojo y tiempo mientras grabas la pantalla"; key: "island.recording" }
        ToggleRow { title: "Fecha al pasar el ratón"; sub: "Fecha en kanji y la microestación del día"; key: "island.hover" }
        ToggleRow { title: "Rueda = volumen"; sub: "Girar la rueda sobre la isla sube o baja el volumen"; key: "island.wheelVolume" }
        ToggleRow { title: "Deslizar para cambiar de canción"; sub: "Con el dedo, en horizontal sobre la isla"; key: "island.swipeTracks" }
        ToggleRow { title: "Aura de la isla"; sub: "Borde fino de 紅 rojo a 金 oro y un brillo rojo suave (sin movimiento)"; key: "island.aura" }
        ToggleRow { title: "Efecto al pasar el ratón"; sub: "Un destello cruza el billete y saltan cuatro pétalos de la estación, una sola vez"; key: "island.hoverFx" }
    }

    SectionTitle { text: "広場 · Hiroba (al pulsar la isla)" }
    Card {
        ToggleRow { title: "Estilo anime"; sub: "Cielo con la hora, bocadillo de saludo, cinta NOW PLAYING, trama de manga y emblema"; key: "hiroba.anime" }
        ToggleRow { title: "Líneas de velocidad"; sub: "Estallan una vez detrás del reloj al abrir"; key: "hiroba.speedLines"; dimmed: !Settings.data.hiroba.anime }
        ToggleRow { title: "Pétalos al abrir"; sub: "Caen una vez, del color de la estación (菊 oro · 桜 rosa · 梅 blanco)"; key: "hiroba.petals"; dimmed: !Settings.data.hiroba.anime }
        ToggleRow { title: "Vinilo que gira"; sub: "Asoma detrás de la portada y gira solo mientras suena"; key: "hiroba.vinyl"; dimmed: !Settings.data.hiroba.anime }
        ToggleRow { title: "Trama de manga"; sub: "Puntos de screentone en las esquinas de las tarjetas"; key: "hiroba.screentone"; dimmed: !Settings.data.hiroba.anime }
        SRow {
            title: "Sello de tu perfil"
            sub: "Un kanji (o una letra) en tu hanko · si existe ~/.face, se usa tu foto"
            TextInput_ {
                Layout.preferredWidth: 90
                implicitHeight: 32
                text: Settings.data.profile.kanji
                placeholder: (Lock.userName || "?").charAt(0)
                onAccepted: Settings.set("profile.kanji", text.trim().slice(0, 2))
            }
        }
    }
    SectionTitle { text: "広場 · Secciones" }
    Card {
        ToggleRow { title: "Tu perfil"; sub: "Saludo, sello, tiempo encendido, bloquear y apagar"; key: "hiroba.sections.me" }
        ToggleRow { title: "Reloj"; sub: "La hora grande con la fecha en kanji"; key: "hiroba.sections.clock" }
        ToggleRow { title: "Gato vibing"; sub: "ネコ cyberpunk que cabecea al ritmo real de la música; clic: reproducir o pausar"; key: "hiroba.sections.neko" }
        ToggleRow { title: "Calendario"; key: "hiroba.sections.month" }
        ToggleRow { title: "Estación y tiempo"; sub: "七十二候, el tiempo de ahora, 3 días y 8 horas"; key: "hiroba.sections.season" }
        ToggleRow { title: "Música"; key: "hiroba.sections.music" }
        ToggleRow { title: "Equipo"; sub: "CPU, GPU, RAM, temperatura, batería y red (solo se mide con 広場 abierto)"; key: "hiroba.sections.system" }
    }
}
