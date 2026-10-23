pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 入力 Teclado y ratón: everything here goes to niri through overrides.kdl (validated before installing).
SetteiPage {
    id: page
    subtitle: "Distribuciones de teclado, repetición, touchpad, TrackPoint y foco. Se aplica al instante en niri."
    resetPaths: ["input", "extras.touchGestures"]
    readonly property var inp: Settings.data.input
    readonly property var known: [
        { id: "es", label: "Español" }, { id: "us", label: "Inglés (EE. UU.)" }, { id: "us(intl)", label: "Inglés internacional" },
        { id: "gb", label: "Inglés (Reino Unido)" }, { id: "latam", label: "Español (Latinoamérica)" }, { id: "fr", label: "Francés" },
        { id: "de", label: "Alemán" }, { id: "it", label: "Italiano" }, { id: "pt", label: "Portugués" },
        { id: "ara", label: "Árabe" }, { id: "ma", label: "Árabe (Marruecos)" }, { id: "jp", label: "Japonés" }
    ]
    function labelOf(id: string): string {
        return (known.find(k => k.id === id) ?? { label: id }).label;
    }
    function setLayouts(l: var): void {
        Settings.set("input.layouts", l.length ? l : ["es"]);
    }

    SectionTitle { text: "Teclado" }
    Card {
        SRow {
            title: "Distribuciones"
            sub: page.inp.layouts.length > 1 ? "La primera es la de inicio" : "Añade otra para cambiar entre ellas"
            Repeater {
                model: page.inp.layouts
                delegate: Rectangle {
                    id: chip
                    required property string modelData
                    required property int index
                    implicitHeight: 30
                    implicitWidth: lay.implicitWidth + 16
                    radius: 10
                    color: index === 0 ? Theme.colors.accentSoft : Theme.colors.surface2
                    border.width: 1
                    border.color: Theme.colors.outline
                    RowLayout {
                        id: lay
                        anchors.centerIn: parent
                        spacing: 4
                        OText { text: page.labelOf(chip.modelData); size: 12.5; font.weight: Font.Medium; color: chip.index === 0 ? Theme.colors.accent : Theme.colors.text }
                        OIcon {
                            visible: page.inp.layouts.length > 1
                            icon: "close"
                            size: 15
                            color: Theme.colors.textMuted
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setLayouts(page.inp.layouts.filter((x, i) => i !== chip.index))
                            }
                        }
                    }
                }
            }
            Dropdown {
                label: "Añadir distribución"
                options: [{ id: "", label: "Añadir…" }].concat(page.known.filter(k => page.inp.layouts.indexOf(k.id) < 0))
                current: ""
                menuWidth: 240
                onPicked: id => { if (id !== "") page.setLayouts(page.inp.layouts.concat([id])); }
            }
        }
        DropRow {
            title: "Cambiar de distribución con"
            dimmed: page.inp.layouts.length < 2
            key: "input.switchKeys"
            options: [{ id: "alt_shift", label: "Alt + Mayús" }, { id: "win_space", label: "Super + Espacio" },
                      { id: "ctrl_shift", label: "Ctrl + Mayús" }, { id: "caps", label: "Bloq Mayús" }, { id: "none", label: "Ninguna" }]
        }
        SliderRow { title: "Retardo de repetición"; sub: "Cuánto mantener una tecla antes de que se repita"; key: "input.repeatDelay"; from: 150; to: 600; stepSize: 10; format: v => Math.round(v) + " ms" }
        SliderRow { title: "Velocidad de repetición"; key: "input.repeatRate"; from: 10; to: 80; stepSize: 1; format: v => Math.round(v) + "/s" }
        SRow {
            title: "Prueba aquí"
            TextInput_ {
                Layout.preferredWidth: 300
                placeholder: "Mantén una tecla pulsada…"
            }
        }
    }

    SectionTitle { text: "Touchpad" }
    Card {
        ToggleRow { title: "Tocar para hacer clic"; key: "input.touchpad.tap" }
        ToggleRow { title: "Desplazamiento natural"; sub: "El contenido sigue a los dedos"; key: "input.touchpad.naturalScroll" }
        ToggleRow { title: "Ignorar mientras escribes"; key: "input.touchpad.dwt" }
        SliderRow { title: "Velocidad del desplazamiento"; sub: "Con dos dedos: listas, páginas, la tira de niri"; key: "input.touchpad.scrollFactor"; from: 0.2; to: 2; stepSize: 0.05; format: v => "×" + v.toFixed(2).replace(".", ",") }
        SliderRow { title: "Velocidad del touchpad"; key: "input.touchpad.speed"; from: -1; to: 1; stepSize: 0.05; format: v => (v >= 0 ? "+" : "") + v.toFixed(2).replace(".", ",") }
    }
    SectionTitle { text: "TrackPoint y ratón" }
    Card {
        SliderRow { title: "Velocidad del TrackPoint"; sub: "Perfil plano (sin aceleración)"; key: "input.trackpointSpeed"; from: -1; to: 1; stepSize: 0.05; format: v => (v >= 0 ? "+" : "") + v.toFixed(2).replace(".", ",") }
        SliderRow { title: "Velocidad del ratón"; key: "input.mouseSpeed"; from: -1; to: 1; stepSize: 0.05; format: v => (v >= 0 ? "+" : "") + v.toFixed(2).replace(".", ",") }
        ToggleRow { title: "El foco sigue al ratón"; sub: "La ventana bajo el puntero recibe el teclado sin hacer clic"; key: "input.ffm" }
        DropRow {
            title: "Con ventanas medio ocultas"
            sub: "Si la ventana bajo el puntero asoma solo en parte, si se enfoca (y la vista se desplaza hasta ella)"
            key: "input.ffmScroll"
            dimmed: !(Settings.data.input.ffm ?? true)
            options: [{ id: "always", label: "Siempre" }, { id: "25", label: "Si apenas hay que desplazar" },
                      { id: "visible", label: "Solo si se ve entera" }]
        }
        ToggleRow { title: "El cursor sigue al foco"; sub: "Al cambiar de ventana con el teclado, el puntero salta a ella"; key: "input.warpMouse" }
    }
    SectionTitle { text: "Pantalla táctil" }
    Card {
        ToggleRow { title: "Gestos táctiles"; sub: "Arrastrar hacia abajo desde el estado abre Engawa; desde la isla, 広場 Hiroba (de lado, otra canción); desde 蛇 o 船, su panel"; key: "extras.touchGestures" }
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
