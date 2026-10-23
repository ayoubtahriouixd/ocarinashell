pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../modules/iro/color.js" as Color

// 色 Iro — eyedropper. `niri msg -j pick-color` (niri ≥ 25.05: the user clicks a pixel, Esc cancels) → the colour
// in #hex / rgb() / oklch() and the closest 伝統色 of colores-nippon.json by OKLab distance; the card (Panels "iro")
// copies a format on click. The last 12 colours are kept in state/iro.json, where Kura shows them.
Singleton {
    id: root

    property var picked: null          // { r, g, b, hex, rgb, oklch }
    // nearest 伝統色, a binding: the palette may still be loading when the first colour arrives
    readonly property var near: picked && palette.length > 0 ? Color.nearest(picked.r, picked.g, picked.b, palette) : null
    property var recent: []
    property var palette: []
    readonly property bool picking: proc.running

    function pick(): void {
        if (proc.running)
            return;
        if (!Settings.data.extras.iro) {
            Osd.show("info", 0, "色 Iro está desactivado en Ajustes → Atajos", "colorize");
            return;
        }
        Panels.close();
        proc.running = true;
    }
    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text]);
        Osd.show("info", 0, "Copiado " + text, "colorize");
    }
    function remember(hex: string): void {
        recent = [hex].concat(recent.filter(h => h !== hex)).slice(0, 12);
        store.setText(JSON.stringify({ version: 1, recent: recent }));
    }
    function status(): string {
        return picked ? JSON.stringify({ hex: picked.hex, rgb: picked.rgb, oklch: picked.oklch,
                                         near: near ? near.color.kanji + " " + near.color.id : "",
                                         distance: near ? near.distance : -1 }) : "{}";
    }
    // also used by tests and by Torii: show the card for a given colour without picking
    function show(hex: string): void {
        if (!/^#?[0-9a-f]{6}$/i.test(hex))
            return;
        const [r, g, b] = Color.hexToRgb(hex);
        const f = Color.formats(r, g, b);
        picked = { r: r, g: g, b: b, hex: f.hex, rgb: f.rgb, oklch: f.oklch };
        remember(f.hex);
        Panels.show("iro", "");
    }

    Process {
        id: proc
        command: ["niri", "msg", "-j", "pick-color"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try {
                    d = JSON.parse(text);
                } catch (e) {}
                const c = d?.PickedColor ?? d;          // tolerate both shapes of the reply
                if (!c?.rgb)
                    return;                             // cancelled
                root.show(Color.hex(c.rgb[0], c.rgb[1], c.rgb[2]));
            }
        }
    }
    FileView {
        path: Paths.asset("data/colores-nippon.json")
        onLoaded: {
            try {
                root.palette = JSON.parse(text()).colors ?? [];
            } catch (e) {}
        }
    }
    FileView {
        id: store
        atomicWrites: true
        path: Paths.state + "/iro.json"
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text()).recent ?? [];
            } catch (e) {}
        }
    }
}
