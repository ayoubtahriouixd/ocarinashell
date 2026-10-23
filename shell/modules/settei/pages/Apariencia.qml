pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 外観 Apariencia (mockup 07): theme cards, traditional accents, interface, motion, fonts, theme by time of day.
SetteiPage {
    id: page
    subtitle: "Tema, acento y tipografía. Los cambios se aplican al instante en la shell, niri, GTK, Qt, Ghostty y Neovim."
    resetPaths: ["appearance"]
    onResetDone: ThemeCtl.setTheme(Settings.data.appearance.theme)

    readonly property var app: Settings.data.appearance
    property var order: []
    FileView {
        path: Paths.asset("data/themes/index.json")
        printErrors: false
        onLoaded: {
            try {
                const idx = JSON.parse(text());
                page.order = (idx.order ?? []).filter(t => t !== idx.powerSaving);
            } catch (e) {}
        }
    }
    readonly property var names: ({ kurenai: "紅 Kurenai", kohaku: "紅白 Kōhaku", sumi: "墨 Sumi", ai: "藍 Ai",
                                    matcha: "抹茶 Matcha", yozakura: "夜桜 Yozakura" })
    readonly property var themeOptions: order.map(id => ({ id: id, label: names[id] ?? id }))

    function fontsFrom(list: var, current: string): var {
        const have = Qt.fontFamilies();
        const out = list.filter(f => have.indexOf(f) >= 0);
        if (out.indexOf(current) < 0)
            out.unshift(current);
        return out.map(f => ({ id: f, label: f }));
    }
    function num(v: real, d: int): string {
        return v.toFixed(d).replace(".", ",");
    }

    SectionTitle { text: "Tema"; topGap: 22 }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 14
        rowSpacing: 14
        Repeater {
            model: page.order
            delegate: ThemeCard {
                required property string modelData
                Layout.fillWidth: true
                themeId: modelData
                selected: Theme.id === modelData
                onPicked: ThemeCtl.setTheme(modelData)
            }
        }
    }

    SectionTitle { text: "Acento · colores tradicionales" }
    RowLayout {
        spacing: 12
        Repeater {
            model: [
                { k: "赤", hex: "#e60033", es: "aka" }, { k: "朱", hex: "#eb6101", es: "shu" },
                { k: "金", hex: "#e6b422", es: "kin" }, { k: "若竹", hex: "#68be8d", es: "wakatake" },
                { k: "浅葱", hex: "#00a3af", es: "asagi" }, { k: "瑠璃", hex: "#1e50a2", es: "ruri" },
                { k: "紫", hex: "#884898", es: "murasaki" }, { k: "紅梅", hex: "#f2a0a1", es: "kōbai" }
            ]
            delegate: AccentSwatch {
                required property var modelData
                swatch: modelData.hex
                name: modelData.k
                hint: modelData.es
                // null = the theme's own accent: it is selected when that colour is the theme's
                selected: page.app.accent === modelData.hex
                    || (page.app.accent === null && String(Theme.tokens.accent ?? "").toLowerCase() === modelData.hex)
                onPicked: ThemeCtl.setAccent(modelData.hex)
            }
        }
        AccentSwatch {
            rainbow: true
            name: "Fondo"
            hint: "desde el fondo de pantalla"
            selected: page.app.accent === "wallpaper"
            onPicked: ThemeCtl.setAccent("wallpaper")
        }
        Item { Layout.fillWidth: true }
        OButton {
            visible: page.app.accent !== null
            ghost: true
            icon: "undo"
            text: "Acento del tema"
            onClicked: ThemeCtl.setAccent(null)
        }
    }
    OText {
        visible: ThemeCtl.error !== ""
        text: "No se pudo aplicar: " + ThemeCtl.error
        color: Theme.colors.error
        size: 12.5
    }

    SectionTitle { text: "Interfaz" }
    Card {
        ToggleRow {
            title: "Transparencias"
            sub: "Superficies de vidrio sobre el fondo (se desactivan en Shinobi)"
            key: "appearance.transparency"
        }
        ToggleRow {
            title: "Desenfoque del compositor"
            sub: "niri ≥ 26.04 · «xray» para barra, isla y paneles"
            key: "appearance.blur"
        }
        SliderRow {
            id: speed
            title: "Velocidad de las animaciones"
            sub: (live <= 0.01 ? "Sin animaciones" : page.num(live, 1) + "×") + " · 0 = sin animaciones (también con «movimiento reducido»)"
            key: "appearance.animSpeed"
            from: 0
            to: 2
            stepSize: 0.25
            showValue: false
            sliderWidth: 220
        }
        ToggleRow {
            title: "Kanji decorativos"
            sub: "Marcas de agua, numerales y sellos"
            key: "appearance.kanjiDecor"
        }
        DropRow {
            title: "Fuente de la interfaz"
            sub: "Texto latino de toda la shell"
            key: "appearance.uiFont"
            options: page.fontsFrom(["Geist", "Inter", "Adwaita Sans", "Cantarell", "Noto Sans", "DejaVu Sans", "Liberation Sans"], page.app.uiFont)
        }
        DropRow {
            title: "Fuente japonesa"
            sub: "Saludos, subtítulos y texto japonés funcional"
            key: "appearance.jpFont"
            options: page.fontsFrom(["Zen Kaku Gothic New", "Noto Sans CJK JP", "M PLUS 1p", "Noto Sans JP"], page.app.jpFont)
        }
        DropRow {
            title: "Fuente decorativa"
            sub: "Kanji de cabeceras, fechas y marcas de agua"
            key: "appearance.displayFont"
            options: page.fontsFrom(["Shippori Mincho B1", "Zen Old Mincho", "Noto Serif CJK JP", "Shippori Mincho"], page.app.displayFont)
        }
        SliderRow {
            title: "Tamaño del texto"
            sub: "Escala de toda la tipografía de la shell"
            key: "appearance.fontScale"
            from: 0.9
            to: 1.3
            stepSize: 0.05
            format: v => Math.round(v * 100) + " %"
        }
        SliderRow {
            title: "Redondez"
            sub: "Radio de paneles, tarjetas y controles"
            key: "appearance.radius"
            from: 0.5
            to: 1.5
            stepSize: 0.1
            format: v => page.num(v, 1) + "×"
        }
        ToggleRow {
            title: "Esquinas de pantalla redondeadas"
            sub: "Cuatro esquinas negras sobre los bordes de cada pantalla"
            key: "appearance.screenCorners"
        }
        ToggleRow {
            title: "Movimiento reducido"
            sub: "Todo estático: cambios instantáneos, sin desplazamientos ni rebotes"
            key: "appearance.reducedMotion"
        }
    }

    SectionTitle { text: "昼夜 · Tema según la hora" }
    Card {
        ToggleRow {
            title: "Tema según la hora"
            sub: page.app.autoTheme.enabled
                ? "Día de " + Kisetsu.sunriseText + " a " + Kisetsu.sunsetText + " (amanecer y atardecer en " + Settings.data.weather.place + ")"
                : "Claro de día y oscuro de noche · se pausa en Shinobi y Oni"
            key: "appearance.autoTheme.enabled"
        }
        DropRow {
            title: "Tema de día"
            key: "appearance.autoTheme.day"
            dimmed: !page.app.autoTheme.enabled
            options: page.themeOptions
        }
        DropRow {
            title: "Tema de noche"
            key: "appearance.autoTheme.night"
            dimmed: !page.app.autoTheme.enabled
            options: page.themeOptions
        }
    }

    SectionTitle { text: "端 Terminal" }
    Card {
        ToggleRow {
            title: "Estela de tinta del cursor"
            sub: "En Ghostty, un trazo rojo de 120 ms al saltar el cursor · solo enchufado, nunca en Shinobi ni con movimiento reducido"
            key: "terminal.inkCursor"
        }
        SliderRow {
            title: "Opacidad de la terminal"
            sub: "Ghostty y Neovim, con el fondo desenfocado detrás · opaca en Shinobi, en Oni o sin transparencias"
            key: "terminal.opacity"
            from: 0.5
            to: 1
            stepSize: 0.02
            format: v => Math.round(v * 100) + " %"
        }
        ToggleRow { title: "Saludo al abrir la terminal"; sub: "こんばんは, la estación y el proverbio del día"; key: "terminal.greeting" }
        ToggleRow { title: "fastfetch la primera vez del día"; sub: "Después, solo con «ff»"; key: "terminal.fastfetchDaily" }
    }
}
