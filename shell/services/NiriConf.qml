pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Settei → niri: renders ~/.local/state/ocarinashell/niri/overrides.kdl (the last include, D-021) from Settings
// (input, windows, animation speed) and installs it through bin/ocarina-niri-gen (validated, atomic). Only owner of
// that file. Written when the rendered text changes (debounced), never on every keystroke.
// niri merges input/layout/animations field by field, but touchpad/trackpoint/mouse/xkb/default-column-width are
// replaced whole and flags cannot be switched off from a later file: those are always written complete here, and
// focus-follows-mouse / warp-mouse-to-focus live only in this file.
Singleton {
    id: root

    property string lastWritten: ""
    property string error: ""
    property bool loaded: false

    function q(s: string): string {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }
    function n(v: real, d: int): string {
        return Number(v).toFixed(d);
    }
    readonly property var switchOptions: ({ alt_shift: "grp:alt_shift_toggle", win_space: "grp:win_space_toggle",
                                            ctrl_shift: "grp:ctrl_shift_toggle", caps: "grp:caps_toggle" })

    readonly property string text: {
        const i = Settings.data.input, w = Settings.data.windows, a = Settings.data.appearance;
        const tp = i.touchpad ?? {};
        const layouts = (i.layouts ?? []).filter(l => /^[a-z]{2,3}(\([a-z0-9_-]+\))?$/i.test(l));
        const L = [];
        L.push("// GENERATED — owner: Settei (設定). Do not edit by hand: Ajustes rewrites it on every change.");
        L.push("// Last include of the niri config (D-021): wins over ocarina/*.kdl field by field.");
        L.push("input {");
        L.push("    keyboard {");
        L.push("        xkb {");
        L.push("            layout " + q((layouts.length ? layouts : ["es"]).map(l => l.replace(/\(.*/, "")).join(",")));
        const variants = (layouts.length ? layouts : ["es"]).map(l => (/\((.*)\)/.exec(l) ?? ["", ""])[1]);
        if (variants.some(v => v !== ""))
            L.push("            variant " + q(variants.join(",")));
        L.push("            model \"pc105\"");
        if (layouts.length > 1 && switchOptions[i.switchKeys])
            L.push("            options " + q(switchOptions[i.switchKeys]));
        L.push("        }");
        L.push("        repeat-delay " + Math.round(i.repeatDelay));
        L.push("        repeat-rate " + Math.round(i.repeatRate));
        L.push("    }");
        L.push("    touchpad {");
        if (tp.tap) L.push("        tap");
        if (tp.dwt) { L.push("        dwt"); L.push("        dwtp"); }
        if (tp.naturalScroll) L.push("        natural-scroll");
        L.push("        click-method \"clickfinger\"");
        L.push("        accel-speed " + n(tp.speed ?? 0.25, 2));
        L.push("        scroll-method \"two-finger\"");
        L.push("        scroll-factor " + n(Math.max(0.1, Math.min(3, tp.scrollFactor ?? 1)), 2));
        L.push("    }");
        L.push("    trackpoint {");
        L.push("        accel-profile \"flat\"");
        L.push("        accel-speed " + n(i.trackpointSpeed, 2));
        L.push("        scroll-method \"on-button-down\"");
        L.push("        scroll-button 274");
        L.push("    }");
        L.push("    mouse {");
        L.push("        accel-speed " + n(i.mouseSpeed, 2));
        L.push("    }");
        // touch screen: mapped to the laptop panel, or off (Settei → Pantalla)
        L.push("    touch {");
        if (i.touch === false)
            L.push("        off");
        else
            L.push("        map-to-output \"" + (Displays.internal?.name ?? "eDP-1") + "\"");
        L.push("    }");
        // how far the view may scroll to focus the window under the pointer (Ayoub, fase 15): «always» no limit ·
        // «25» a partly hidden one only if it is mostly in view · «visible» 2 % — not 0 %: two half-width columns
        // plus gaps are 1.3 logical px wider than the 1645 px panel (1,75), so with 0 % the neighbour never took focus
        if (i.ffm)
            L.push(i.ffmScroll === "always" ? "    focus-follows-mouse"
                   : "    focus-follows-mouse max-scroll-amount=\"" + (i.ffmScroll === "visible" ? "2%" : "25%") + "\"");
        if (i.warpMouse) L.push("    warp-mouse-to-focus");
        L.push("}");
        L.push("layout {");
        L.push("    gaps " + Math.round(w.gaps));
        L.push("    default-column-width { proportion " + n(w.defaultWidth, 5) + "; }");
        L.push("    focus-ring {");
        L.push(w.focusRing ? "        on" : "        off");
        L.push("        width " + Math.max(1, Math.round(w.focusRingWidth)));
        L.push("    }");
        L.push("}");
        // lid closed with a monitor: niri switches the panel off by itself; this keeps it on when not wanted
        if (Settings.data.display.lidCloseToExternal === false && keepPanelSupported) {
            L.push("debug {");
            L.push("    keep-laptop-panel-on-when-lid-is-closed");
            L.push("}");
        }
        const speed = Number(a.animSpeed) || 0;
        L.push("animations {");
        if (!w.niriAnimations || speed <= 0.01 || a.reducedMotion)
            L.push("    off");
        else
            L.push("    slowdown " + n(1 / Math.max(0.5, Math.min(2, speed)), 3));
        L.push("}");
        return L.join("\n") + "\n";
    }

    // debug options are unstable in niri: probe once that this version still knows the lid one (else it is
    // simply left out, instead of freezing the whole file on a validation error)
    property bool keepPanelSupported: false
    Process {
        running: true
        command: ["sh", "-c", 'f="$(mktemp --suffix=.kdl)"; printf "debug {\n    keep-laptop-panel-on-when-lid-is-closed\n}\n" > "$f"; '
                  + 'niri validate -c "$f" >/dev/null 2>&1; r=$?; rm -f "$f"; exit $r']
        onExited: code => root.keepPanelSupported = code === 0
    }

    onTextChanged: if (loaded) debounce.restart()
    Timer {
        id: debounce
        interval: 500
        onTriggered: root.write()
    }
    function write(): void {
        if (!Settings.ready || text === lastWritten)
            return;
        if (gen.running) {
            debounce.restart();
            return;
        }
        gen.pending = text;
        gen.command = ["sh", "-c", 'printf "%s" "$1" | "$0" apply overrides', Paths.bin + "/ocarina-niri-gen", text];
        gen.running = true;
    }
    Process {
        id: gen
        property string pending: ""
        stderr: StdioCollector { id: genErr }
        onExited: code => {
            if (code === 0) {
                root.lastWritten = pending;
                if (root.error !== "")
                    Health.ok("Ajustes de niri (overrides.kdl)");
                root.error = "";
            } else {
                root.error = genErr.text.trim() || "niri no aceptó la configuración";
                console.warn("NiriConf: overrides.kdl rechazado:", root.error);
                Health.fail("Ajustes de niri (overrides.kdl)", root.error);
            }
        }
    }
    // start: compare with what is on disk (written by a previous session) and write only if different
    FileView {
        path: Paths.state + "/niri/overrides.kdl"
        printErrors: false
        onLoaded: { root.lastWritten = text(); root.loaded = true; root.write(); }
        onLoadFailed: { root.loaded = true; root.write(); }
    }
    Connections {
        target: Settings
        function onReadyChanged() { if (root.loaded) root.write(); }
    }
}
