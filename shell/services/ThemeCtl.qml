pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Theme orchestration for Settei and IPC: one place that runs bin/ocarina-theme, so Settings.appearance (theme,
// accent, autoTheme) and the engine's theme.json never disagree.
//   accent: null = the theme's own · "#rrggbb" = traditional colour · "wallpaper" = from the current wallpaper
//   (re-derived when the wallpaper changes). autoTheme: day theme from sunrise to sunset (Kisetsu), night theme
//   otherwise; checked on the minute tick only while enabled, paused in Shinobi/Oni.
Singleton {
    id: root

    readonly property var cfg: Settings.data.appearance
    property bool busy: run.running
    property string error: ""
    property var queued: null

    readonly property string wallpaper: Wallpapers.current

    function command(themeId: string, accent: var): list<string> {
        if (accent === "wallpaper" && wallpaper !== "")
            return [Paths.bin + "/ocarina-theme", "from-wallpaper", wallpaper, "--theme", themeId, "--quiet"];
        if (typeof accent === "string" && /^#[0-9a-fA-F]{6}$/.test(accent))
            return [Paths.bin + "/ocarina-theme", "apply", themeId, "--accent", accent, "--quiet"];
        return [Paths.bin + "/ocarina-theme", "apply", themeId, "--quiet"];
    }
    // 忍 Shinobi owns the theme while it is on: requests are saved in Settings (Settei, IPC, the wallpaper accent)
    // and applied when the mode ends. hold()/release() are only for Modes.
    property string heldBy: ""
    function hold(themeId: string): void {
        heldBy = themeId;
        queued = null;
        go(command(themeId, null));
    }
    function release(): void {
        heldBy = "";
        // accent «from the wallpaper»: Shinobi has no wallpaper, so derive it again once the real one is back
        rederive = cfg.accent === "wallpaper";
        exec(cfg.autoTheme.enabled ? autoTarget() : cfg.theme, rederive && wallpaper === "" ? null : cfg.accent);
        if (wallpaper !== "")
            rederive = false;
    }
    property bool rederive: false
    function exec(themeId: string, accent: var): void {
        if (heldBy !== "")
            return;
        go(command(themeId, accent));
    }
    function go(cmd: var): void {
        if (run.running) {
            queued = cmd;          // the last request wins
            return;
        }
        error = "";
        run.command = cmd;
        run.running = true;
    }

    function setTheme(id: string): void {
        if (id === "")
            return;
        if (cfg.theme !== id)
            Settings.set("appearance.theme", id);
        exec(id, cfg.accent);
    }
    function setAccent(a: var): void {
        Settings.set("appearance.accent", a);
        exec(Theme.id, a);
    }
    // used by `ocarina theme`/IPC: same bookkeeping as Settei
    function applyFromIpc(id: string, accent: var): void {
        Settings.set("appearance.theme", id);
        if (accent !== undefined)
            Settings.set("appearance.accent", accent);
        exec(id, accent !== undefined ? accent : cfg.accent);
    }

    // accent «from the wallpaper» follows wallpaper changes
    property string lastWall: ""
    onWallpaperChanged: {
        if (wallpaper !== "" && (rederive || (lastWall !== "" && wallpaper !== lastWall)) && cfg.accent === "wallpaper") {
            rederive = false;
            exec(Theme.id, "wallpaper");
        }
        lastWall = wallpaper;
    }

    // ── 昼夜 theme by the time of day ─────────────────────────────────────────────────────────
    readonly property bool autoOn: cfg.autoTheme.enabled && !Modes.shinobi && !Modes.oni
    function autoTarget(): string {
        const now = Time.now.getTime();
        const rise = Kisetsu.sunrise.getTime(), set = Kisetsu.sunset.getTime();
        let day;
        if (isNaN(rise) || isNaN(set)) {
            const h = Time.now.getHours();
            day = h >= 7 && h < 20;
        } else {
            day = now >= rise && now < set;
        }
        return day ? cfg.autoTheme.day : cfg.autoTheme.night;
    }
    function checkAuto(): void {
        if (!autoOn || run.running)
            return;
        const t = autoTarget();
        if (t && t !== Theme.id)
            setTheme(t);
    }
    onAutoOnChanged: checkAuto()
    Connections {
        target: root.autoOn ? Time : null
        function onMinuteTick() { root.checkAuto(); }
    }
    Connections {
        target: Settings
        function onDataChanged() { if (root.autoOn) Qt.callLater(root.checkAuto); }
    }

    Process {
        id: run
        stderr: StdioCollector { id: errOut }
        onExited: code => {
            root.error = code === 0 ? "" : (errOut.text.trim().split("\n").pop() || "el motor de temas falló");
            if (code !== 0)
                console.warn("ThemeCtl:", root.error);
            if (root.queued) {
                const c = root.queued;
                root.queued = null;
                run.command = c;
                run.running = true;
            }
        }
    }
}
