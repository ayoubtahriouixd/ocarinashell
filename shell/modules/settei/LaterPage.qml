import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Navigation slot of a module that arrives in a later phase (Fune, Snake, Mamori, Nameraka): says which and what
// it will do, nothing else (no fake controls).
SetteiPage {
    id: root
    readonly property int phase: Settei.later[Settei.page] ?? 0
    readonly property var blurb: ({
        nameraka: "Generación de fotogramas para vídeo a pantalla completa (Lossless Scaling o IA): modo, motor, calidad, calibración y exclusiones por app.",
        fune: "Apps de Windows en una máquina virtual ligera: estado, recursos, apps fijadas, pausa automática y mantenimiento.",
        snake: "Asistente de IA local: modelo, motor (Vulkan o NPU), memoria, fuentes de contexto y uso con batería.",
        mamori: "Mantenimiento autónomo: actualizaciones con snapshot, pruebas y vuelta atrás; retenciones, salud del equipo e informe semanal."
    })
    subtitle: blurb[Settei.page] ?? ""
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 22
        implicitHeight: 150
        radius: Theme.radius.card
        color: Theme.colors.surface1
        border.width: 1
        border.color: Theme.colors.outline
        Kanji {
            anchors.right: parent.right
            anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            visible: Settings.data.appearance.kanjiDecor
            text: Settei.pageInfo.glyph
            size: 96
            opacity: 0.07
        }
        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Chip {
                kanji: "待"
                text: root.phase > 0 ? "Llega en la fase " + root.phase : "Más adelante"
                tone: "red"
            }
            OText {
                text: "Esta página se activa sola cuando el módulo esté construido."
                size: 13.5
                color: Theme.colors.textMuted
            }
        }
    }
}
