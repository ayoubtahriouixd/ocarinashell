pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens (docs/02-DISENO). Colours come from ~/.local/state/ocarinashell/theme.json, written by
// bin/ocarina-theme; the file is watched and every colour fades with Motion.slow when the theme changes.
// Nothing in the shell may use a literal colour, size or font name: always Theme.*.
Singleton {
    id: root

    property var tokens: ({})
    property var engineState: ({})       // theme.json without tokens: id, accent, accent2, applied
    readonly property string id: tokens.id ?? "kurenai"
    readonly property string name: tokens.name ?? "Kurenai"
    readonly property string kanji: tokens.kanji ?? "紅"
    readonly property bool dark: String(tokens.isDark ?? true) === "true"
    readonly property string wallpaper: tokens.wallpaper ?? ""

    // "#RRGGBBAA" (CSS, theme.json) → "#AARRGGBB" (Qt)
    function qc(v: var, fallback: string): color {
        const s = String(v ?? fallback);
        const m = /^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(s);
        if (!m)
            return fallback;
        return m[2] ? "#" + m[2] + m[1] : "#" + m[1];
    }
    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // Fallbacks = Kurenai, so the shell is never colourless before the first `ocarina-theme apply`.
    readonly property Item colors: Item {
        property color bg: root.qc(root.tokens.bg, "#0b0a0c")
        property color surface0: root.qc(root.tokens.surface0, "#141216")
        property color surface1: root.qc(root.tokens.surface1, "#1b181d")
        property color surface2: root.qc(root.tokens.surface2, "#241f26")
        property color surface3: root.qc(root.tokens.surface3, "#2e2830")
        property color outline: root.qc(root.tokens.outline, "#2c262e")
        property color outlineStrong: root.qc(root.tokens.outlineStrong, "#463e48")
        property color text: root.qc(root.tokens.text, "#f4efe6")
        property color textMuted: root.qc(root.tokens.textMuted, "#aaa39b")
        property color textDim: root.qc(root.tokens.textDim, "#878079")
        property color accent: root.qc(root.tokens.accent, "#e60033")
        property color accentHover: root.qc(root.tokens.accentHover, "#ff1f4f")
        property color accentSoft: root.qc(root.tokens.accentSoft, "#e6003329")
        // hover/press fill under accentInk: darker, never lighter, so the label keeps AA (tests/contraste.py)
        readonly property color accentPressed: Qt.darker(accent, 1.12)
        // "onAccent" cannot be a QML property name (on + Capital = signal handler): it read as undefined (black)
        property color accentInk: root.qc(root.tokens.onAccent, "#ffffff")
        property color accent2: root.qc(root.tokens.accent2, "#e6b422")
        property color success: root.qc(root.tokens.success, "#68be8d")
        property color warning: root.qc(root.tokens.warning, "#f8b500")
        property color error: root.qc(root.tokens.error, "#ff4d6a")
        property color info: root.qc(root.tokens.info, "#a0d8ef")
        property color shadow: root.qc(root.tokens.shadow, "#00000099")
        property color scrim: root.qc(root.tokens.scrim, "#0000006b")
        // lean (Shinobi): opaque black cards on a black desktop need a visible edge (mockup 06: #1a1a1a)
        property color glassBorder: root.lean ? surface3 : root.qc(root.tokens.glassBorder, "#ffffff12")
        property color glassHighlight: root.qc(root.tokens.glassHighlight, "#ffffff0b")
        property color asagi: root.qc(root.tokens.focusWindows, "#00a3af")
        property color sakura: root.qc(root.tokens.sakura, "#f37f8f")      // Kagi's petals (mockup 03)
        // on top of pictures (thumbnails, previews) and slider knobs: same in every theme
        readonly property color knob: "#ffffff"
        readonly property color onImage: "#ffffff"
        readonly property color imageScrim: "#b0000000"
        readonly property color imageChip: "#8c000000"
        // Shima and 広場 Hiroba: ink-black in the dark themes (docs/02-DISENO §5) and paper in the light ones (Ayoub,
        // fase 17: «que sea clara tanto ella como su menú»). The rest of the shell reads only these tokens.
        readonly property bool islandLight: !root.dark
        readonly property color island: islandLight ? surface0 : "#050405"
        readonly property color islandBorder: islandLight ? "#1a000000" : "#12ffffff"
        readonly property color islandText: islandLight ? text : "#f4efe6"
        readonly property color islandMuted: islandLight ? textMuted : "#aaa39b"
        readonly property color islandDim: islandLight ? textDim : "#878079"
        readonly property color islandFaint: islandLight ? root.mix(textDim, surface0, 0.55) : "#3d3739"
        readonly property color islandCard: islandLight ? "#08000000" : "#09ffffff"   // Hiroba cards: 3,5 % on the ink
        readonly property color islandLine: islandLight ? "#12000000" : "#11ffffff"   // and their 1 px border
        readonly property color islandSep: islandLight ? "#14000000" : "#12ffffff"
        // buttons on the island: rest · hover · track · tick
        readonly property color islandRest: islandLight ? "#0b000000" : "#0fffffff"
        readonly property color islandHover: islandLight ? "#18000000" : "#1fffffff"
        readonly property color islandTrack: islandLight ? "#14000000" : "#14ffffff"
        readonly property color islandTick: islandLight ? "#2a000000" : "#2affffff"
        readonly property color paper: "#ffffff"                   // manga speech bubble
        readonly property color paperInk: "#18171c"
        readonly property color paperMuted: "#5f5953"
        // 鬼 Oni is always 紅 on ink with a gold rim, whatever the theme (mockups 02/08: .hk.oni, .mode.oni.on)
        readonly property color oni: "#e60033"
        readonly property color oniDeep: "#8a001f"
        readonly property color oniEdge: "#ff4d6a"
        readonly property color oniGold: "#e6b422"
        readonly property color oniInk: "#050405"
        // the boot chain (Limine, Plymouth, greeter, farewell) has two fixed variants, never the theme's own bg:
        // tools/boot_assets.py VAR — keep them identical or the hand-over shows a seam
        readonly property color bootDark: "#0b0a0c"
        readonly property color bootLight: "#f4f1ec"
        readonly property color bootNoteDark: "#a8a199"          // Plymouth's system message (0.66, 0.63, 0.60)
        readonly property color bootNoteLight: "#615c54"         // (0.38, 0.36, 0.33)
        readonly property color bootInkDark: "#f4efe6"
        readonly property color bootInkLight: "#18171c"
        readonly property color bootMutedDark: "#8a847d"
        readonly property color bootMutedLight: "#615b55"

        Behavior on bg { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on surface0 { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on surface1 { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on surface2 { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on surface3 { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on outline { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on outlineStrong { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on text { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on textMuted { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on textDim { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on accent { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on accentHover { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on accentSoft { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on accent2 { ColorAnimation { duration: Motion.fade(Motion.slow) } }
        Behavior on glassBorder { ColorAnimation { duration: Motion.fade(Motion.slow) } }
    }

    readonly property color oledBlack: "#000000"      // 忍 Shinobi: pixels off on the OLED panel
    // lean: written by Modes (忍 Shinobi, 鬼 Oni): no blur and no transparency whatever the settings say
    property bool lean: false
    readonly property bool blur: Settings.data.appearance.blur && !lean
    readonly property bool transparency: Settings.data.appearance.transparency && !lean
    readonly property real glassAlpha: Number(tokens.glassAlpha ?? 0.72)
    // lean (Shinobi/Oni): no blur behind, so nothing may show through either (mockup 06: opaque cards)
    readonly property real glassOpaqueAlpha: lean ? 1 : Number(tokens.glassOpaqueAlpha ?? 0.94)

    readonly property QtObject font: QtObject {
        readonly property string ui: Settings.data.appearance.uiFont
        readonly property string jp: Settings.data.appearance.jpFont
        readonly property string display: Settings.data.appearance.displayFont
        readonly property string brush: "Yuji Syuku"
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string brand: "Unbounded"
        readonly property string icon: "Material Symbols Rounded"
        readonly property string emoji: "Noto Color Emoji"
        readonly property real scale: Settings.data.appearance.fontScale
        // type scale (docs/02-DISENO §2), logical px — OText/Kanji/OIcon multiply by `scale`
        readonly property real caption: 11.5
        readonly property real meta: 12           // mock.css 12 px: secondary lines of panels (Fune, Engawa)
        readonly property real small: 12.5
        readonly property real body: 13.5
        readonly property real title: 15
        readonly property real h3: 18
        readonly property real h2: 22
        readonly property real h1: 26
        readonly property real display48: 48
    }

    readonly property QtObject radius: QtObject {
        readonly property real k: Settings.data.appearance.radius
        readonly property real bar: 14 * k
        readonly property real island: 15
        readonly property real panel: 22 * k
        readonly property real card: 16 * k
        readonly property real control: 10 * k
        readonly property real chip: 13 * k
        readonly property real menu: 12 * k
        readonly property real hanko: 8
    }

    // Obi / Shima geometry (docs/02-DISENO §5, assets/mockups/src/mock.css)
    readonly property QtObject bar: QtObject {
        readonly property real top: 8
        readonly property real side: 10
        readonly property real height: 40
        readonly property real padLeft: 12
        readonly property real padRight: 8
        readonly property real gap: 10
        readonly property real cell: 26
        readonly property real cellGap: 4
        readonly property real icon: 18
    }
    readonly property QtObject island: QtObject {
        readonly property real top: 13
        readonly property real hirobaTop: root.bar.top * 2 + root.bar.height   // 広場 opens under the bar (it stays)
        readonly property real panelWidth: 1056        // 広場 Hiroba (mockup 14 at 1100, a touch smaller: Ayoub)
        readonly property real panelRadius: 30
        readonly property real cardRadius: 20
        readonly property real panelHeight: 616            // 22 + 150 + 14 + 300 + 14 + 94 + 22
        readonly property real rowTop: 150
        readonly property real rowMid: 300
        readonly property real rowSys: 94
        readonly property real sideCard: 284               // you · 招き猫 · music
        readonly property real monthCard: 300
        readonly property real height: 30
        readonly property real musicHeight: 38
        readonly property real osdWidth: 260
        readonly property real osdHeight: 44
        readonly property real hoverHeight: 54
        readonly property real ticketHeight: 58          // 島 v2 hover «ticket» (mockup 17)
        readonly property real musicMaxWidth: 360
        readonly property real maxWidth: 520
    }

    function space(n: real): real {
        return 4 * n;
    }

    FileView {
        path: Paths.theme
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && d.tokens) {
                    root.tokens = d.tokens;
                    root.engineState = { id: d.id, accent: d.accent ?? null, accent2: d.accent2 ?? null };
                }
            } catch (e) {
                console.warn("Theme: theme.json no válido, se mantiene el tema anterior:", e);
            }
        }
    }
}
