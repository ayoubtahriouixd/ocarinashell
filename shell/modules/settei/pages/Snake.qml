pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 蛇 Snake (phase 15, D-008, docs/SNAKE.md): the local AI. State and «Probar ahora», the model and the engine, how
// long it stays loaded, battery, and what it may read. The assistant itself is Mod+Shift+A (or the 蛇 in the bar).
SetteiPage {
    id: page
    subtitle: "Tu IA local y gratuita: corre en el portátil, sin nube ni cuentas. Se carga al usarla y se descarga sola."
    resetPaths: ["snake"]
    readonly property var s: Settings.data.snake

    Component.onCompleted: {
        Snake.refresh();
        Snake.loadModels();
    }

    SectionTitle { text: "Estado" }
    Card {
        SRow {
            title: Snake.loaded ? "Cargado · " + Snake.name : Snake.starting ? "Cargando " + Snake.name + "…"
                 : "Parado · 0 MB"
            sub: Snake.loaded ? "Responde al momento; se descarga a los " + (page.s.keepAliveMin ?? 5) + " min sin uso"
                : !Snake.modelPresent ? "El modelo no está descargado: ocarina snake models pull " + Snake.model
                : Snake.canLoad ? "Se carga al preguntar (unos segundos la primera vez)"
                : Snake.policy
            OButton {
                text: "Probar ahora"
                icon: "play_arrow"
                enabled: page.s.enabled && Snake.modelPresent && !Snake.busy
                onClicked: Snake.test()
            }
            OButton {
                visible: Snake.loaded
                text: "Liberar memoria"
                onClicked: Snake.stop()
            }
        }
        ToggleRow {
            title: "Snake activado"
            sub: "Apagado, ni el asistente ni 守 Mamori lo cargan (Mamori sigue en modo determinista)"
            key: "snake.enabled"
        }
    }

    SectionTitle { text: "Modelo" }
    Card {
        DropRow {
            title: "Modelo principal"
            sub: "Elegido por la evaluación de docs/SNAKE.md; Mamori prueba modelos nuevos cada mes"
            key: "snake.model"
            options: [{ id: "", label: "El recomendado" }].concat(Snake.models.map(m => ({
                id: m.id, label: m.name + " · " + (m.size / 1073741824).toFixed(1) + " GB" + (m.present ? "" : " (sin descargar)") })))
        }
        SRow {
            title: "Motor · GPU (Vulkan)"
            sub: "La Radeon 860M con salidas JSON garantizadas. La NPU se evaluó y no las garantiza: queda solo para pruebas (docs/SNAKE.md)"
        }
        DropRow {
            title: "Contexto"
            sub: "Cuánto texto lee de una vez; más contexto, más memoria"
            key: "snake.ctx"
            options: [{ id: 8192, label: "8 k" }, { id: 16384, label: "16 k" }, { id: 32768, label: "32 k" }]
        }
    }

    SectionTitle { text: "声 Voz" }
    Card {
        DropRow {
            title: "Idioma al hablar"
            sub: "Whisper large-v3-turbo en tu equipo (GPU si hay sitio, si no CPU) · el micrófono, el panel o Super+Alt+A · el audio solo vive en RAM"
            key: "snake.voiceLang"
            options: [{ id: "es", label: "Español" }, { id: "auto", label: "Detectar" }, { id: "en", label: "Inglés" },
                      { id: "fr", label: "Francés" }, { id: "ar", label: "Árabe" }, { id: "ja", label: "Japonés" }]
        }
    }

    SectionTitle { text: "Memoria y energía" }
    Card {
        SliderRow {
            title: "Descargar tras"
            sub: "Minutos sin preguntas hasta liberar la memoria (vuelve a 0 MB)"
            key: "snake.keepAliveMin"
            from: 1; to: 60; stepSize: 1
            format: v => Math.round(v) + " min"
        }
        ToggleRow {
            title: "Asistente con batería"
            sub: "Con batería solo responde cuando le preguntas tú (con aviso); las tareas de fondo esperan al cargador"
            key: "snake.batteryAssistant"
        }
        SRow {
            title: "Nunca en 忍 Shinobi ni en 鬼 Oni"
            sub: "Al entrar en cualquiera de los dos se descarga al momento; y solo se carga si queda RAM libre para el modelo + 4 GB"
        }
    }

    SectionTitle { text: "Privacidad" }
    Card {
        SRow {
            title: "Todo en tu equipo"
            sub: "El modelo corre sin red, en un socket local que solo tú puedes abrir. La red solo se usa para leer noticias y changelogs de una lista blanca (Arch, CachyOS, GitHub, GitLab, wikis): lo que lee es dato, nunca una orden"
        }
        SRow {
            title: "Nunca ejecuta nada por su cuenta"
            sub: "Propone acciones de una lista cerrada y solo se ejecutan si pulsas «Ejecutar». No lee tus documentos: solo el contexto que adjuntas"
        }
        SRow {
            title: "Registro"
            sub: "Todo lo que hace queda en el journal: journalctl -t ocarina-snake"
        }
    }
}
