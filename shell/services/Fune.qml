pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 船 Fune — Windows apps as native windows (docs/01-ARQUITECTURA §16, fase 12, D-062). bin/ocarina-fune does the work
// (rootless Podman + dockur/windows + FreeRDP RemoteApp); the shell shows the state and owns the policy:
// - state: `ocarina-fune status --json` once, then `podman events` ONLY while the VM is on or paused (with it off,
//   0 processes: the CLI tells us over IPC when it starts it). dockur has no healthcheck, so events are real changes;
// - RemoteApp windows (app-id fune-*) counted from niri's own window events: no polling;
// - automatic pause after N min without Windows windows (0 % CPU, RAM kept) and shutdown after M min paused (RAM
//   freed); 忍 Shinobi pauses at once and stops after 5 min; 鬼 Oni pauses when no Windows app is open. The CLI has the
//   last word (`--auto` exits 3 = «not now»: maintenance, first install, an app connecting) and we then wait for
//   something to change before asking again;
// - stats: one long-lived `podman stats --interval 2` only while the panel shows them (docs/04-RENDIMIENTO).
Singleton {
    id: root

    readonly property var cfg: Settings.data.fune
    readonly property string cli: Paths.bin + "/ocarina-fune"

    // ── state ───────────────────────────────────────────────────────────────────────────────
    property bool checked: false           // the first status arrived (or failed)
    property bool available: true          // podman + podman-compose + xfreerdp3 (docs/01 §13: else Fune hides)
    property string unavailableReason: ""
    property bool installed: false
    property string state: "missing"       // missing | exited | running | paused | stopping | created…
    property bool ready: false             // RDP answers
    property bool setupDone: false         // the first install finished (an app scan happened)
    property bool hold: false              // `ocarina fune maintenance` is running
    property real since: 0                 // ms epoch of the last start
    property real pausedSince: 0           // ms epoch of the last pause (survives a shell restart)
    property var vm: ({ cores: 4, ram: 0, disk: 0, diskUsed: 0, version: "11" })
    property bool waking: false            // the CLI is booting Windows for an app (island hint)
    property bool busy: false              // an action of ours is running
    property string busyAction: ""         // which one («pause», «stop», «scan»…) for the buttons' labels
    property string lastError: ""
    readonly property bool running: state === "running"
    readonly property bool paused: state === "paused"
    readonly property bool stopping: state === "stopping"
    readonly property bool on: running || paused || stopping
    readonly property bool off: installed && !on
    readonly property bool booting: running && !ready
    readonly property bool installing: running && !setupDone && !ready
    readonly property string label: !checked ? "Comprobando…" : !available ? "No disponible" : !installed ? "Sin instalar"
        : stopping ? "Apagándose" : paused ? "En pausa" : installing ? "Instalando Windows"
        : booting ? "Arrancando" : running ? "Activa" : "Apagada"
    readonly property string tone: running && ready ? "ok" : paused || booting || stopping ? "warn" : "off"

    // RemoteApp windows niri has right now (the full desktop counts too; web apps are not Windows)
    readonly property int windows: {
        let n = 0;
        for (const id in Niri.windows) {
            const w = Niri.windows[id];
            const a = String(w?.app_id ?? "");
            // RemoteApp's invisible helpers (untitled, «RemoteApp Marker Window») are not apps
            if (a.startsWith("fune-") && !a.startsWith("fune-web-") && w.title !== "" && w.title !== "RemoteApp Marker Window")
                n++;
        }
        return n;
    }

    // FreeRDP maps some invisible helper windows of the Windows session (untitled, or «RemoteApp Marker Window") as
    // real toplevels: the niri rule makes them transparent; here, the ones still untitled after 1,5 s leave the
    // tiling (floating, minimum size, pushed to a corner) so they take no column and no focus
    readonly property var helperWindows: {
        const ids = [];
        for (const id in Niri.windows) {
            const w = Niri.windows[id];
            const a = String(w?.app_id ?? "");
            if (a.startsWith("fune-") && !a.startsWith("fune-web-") && a !== "fune-desktop" && !w.is_floating
                    && (w.title === "" || w.title === "RemoteApp Marker Window"))
                ids.push(Number(id));
        }
        return ids;
    }
    onHelperWindowsChanged: if (helperWindows.length > 0) helperLater.restart()
    Timer {
        id: helperLater
        interval: 1500
        onTriggered: {
            for (const id of root.helperWindows) {
                const focused = Niri.windows[id]?.is_focused ?? false;
                Quickshell.execDetached(["sh", "-c", 'niri msg action move-window-to-floating --id "$0" && '
                    + 'niri msg action set-window-width --id "$0" 1 && niri msg action set-window-height --id "$0" 1 && '
                    + 'niri msg action move-floating-window --id "$0" -x 9999 -y 9999' + (focused ? " && niri msg action focus-tiling" : ""),
                    String(id)]);
            }
        }
    }

    // apps (level 2), web apps (level 0) and Wine apps (level 1), from the CLI
    property var apps: []
    property int webCount: 0
    property int wineCount: 0

    // stats while the panel is open
    property int statsUsers: 0
    property real cpu: 0                   // 0–1 of all vCPUs
    property real mem: 0                   // bytes
    property bool statsFresh: false        // at least one reading since the panel opened
    readonly property int cores: vm.cores ?? 4
    readonly property real memMax: vm.ram ?? 0
    readonly property real disk: vm.diskUsed ?? 0
    readonly property real diskMax: vm.disk ?? 0

    // ── public (IPC `fune`, panel, Settei) ──────────────────────────────────────────────────
    function start(): void { act(["start"]); }
    function pause(): void { act(["pause"]); }
    function resume(): void { act(["resume"]); }
    function stop(): void { act(["stop"]); }
    function desktop(): void { Quickshell.execDetached([cli, "desktop"]); }      // the CLI calls opened() over IPC
    function launch(id: string): void { Quickshell.execDetached([cli, "app", id]); }
    function scan(): void { act(["scan"]); }
    function forget(id: string): void { act(["forget", id]); }
    function webapp(name: string, url: string): void { act(["webapp", name, url]); }
    function status(): string {
        return JSON.stringify({ available: available, installed: installed, state: state, ready: ready,
                                setupDone: setupDone, since: since, windows: windows, apps: apps.length, web: webCount,
                                wine: wineCount, waking: waking, autoHeld: autoHeld, wantPause: wantPause });
    }
    // from the CLI
    function wake(): void {
        waking = true;
        wakeSafety.restart();
        refresh();
    }
    function wokeUp(): void {
        waking = false;
        refresh();
    }

    function act(args: var): void {
        if (actProc.running)
            return;
        busy = true;
        busyAction = args[0];
        lastError = "";
        actProc.auto = args.indexOf("--auto") >= 0;
        // a transient unit runs it: a shell reload or crash must never cut a stop, an update or a backup in half
        // (--wait/--pipe still give us its exit code and stderr)
        actProc.command = ["systemd-run", "--user", "--quiet", "--collect", "--wait", "--pipe", "--", cli].concat(args);
        actProc.running = true;
    }
    function refresh(): void {
        if (!statusProc.running)
            statusProc.running = true;
        else
            refreshAgain.restart();
    }
    function refreshApps(): void {
        if (!appsProc.running)
            appsProc.running = true;
    }
    function fmtGB(b: real): string {
        return (b / 1073741824).toLocaleString(Qt.locale("es_ES"), "f", 1);
    }

    Timer {
        id: refreshAgain
        interval: 300
        onTriggered: root.refresh()
    }
    Timer {
        id: wakeSafety                     // the CLI always says «ready» at the end; this is only the net under it
        interval: 300000
        onTriggered: root.waking = false
    }
    onReadyChanged: if (ready) waking = false
    onStateChanged: if (state !== "running") waking = false

    Process {
        id: statusProc
        command: [root.cli, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = null;
                try {
                    s = JSON.parse(text);
                } catch (e) {}
                if (!s) {
                    root.checked = true;
                    return;
                }
                root.available = s.podman === true && s.freerdp === true;
                root.unavailableReason = s.podman !== true ? "Falta Podman (sudo pacman -S podman podman-compose)"
                    : s.freerdp !== true ? "Falta FreeRDP (sudo pacman -S freerdp)" : "";
                root.installed = s.installed === true;
                root.state = s.state ?? "missing";
                root.ready = s.ready === true;
                root.setupDone = s.setupDone === true;
                root.hold = s.hold === true;
                root.since = s.since ? Date.parse(s.since) : 0;
                root.pausedSince = (s.pausedSince ?? 0) * 1000;
                root.vm = s.vm ?? root.vm;
                root.checked = true;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.checked = true;
                root.available = false;
                root.unavailableReason = "ocarina-fune no responde (ocarina doctor)";
            }
        }
    }
    Process {
        id: appsProc
        command: [root.cli, "apps", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.apps = j.apps ?? [];
                    root.webCount = j.web ?? 0;
                    root.wineCount = j.wine ?? 0;
                } catch (e) {}
            }
        }
    }
    Process {
        id: actProc
        property bool auto: false
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim().replace(/^船 /, "");
                if (t !== "")
                    root.lastError = t.split("\n").pop();
            }
        }
        // `exited` never comes when the CLI cannot even start: `running` going false always does
        onRunningChanged: if (!running) Qt.callLater(root.actDone)
        onExited: (code, status) => {
            if (auto && code === 3)
                root.autoHeld = true;       // «not now»: wait until something changes (see autoHeld)
            else if (code !== 0 && !auto && root.lastError !== "")
                Osd.show("info", 0, "Windows: " + root.lastError, "sailing");
        }
    }
    function actDone(): void {
        busy = false;
        busyAction = "";
        refresh();
        refreshApps();
    }

    // podman events: only while there is something to watch (an off VM changes only through our CLI). Set, never
    // bound: Process writes `running` itself when it exits. A crash-looping events backend backs off up to 60 s.
    readonly property bool watchWanted: installed && on
    onWatchWantedChanged: events.running = watchWanted
    property int eventsBackoff: 2000
    Process {
        id: events
        command: ["podman", "events", "--format", "{{.Status}}", "--filter", "container=WinApps", "--filter", "type=container"]
        stdout: SplitParser {
            onRead: line => {
                root.eventsBackoff = 2000;
                refreshAgain.restart();
            }
        }
        onStarted: root.refresh()          // a change between our last status and the start must not be lost
        onExited: if (root.watchWanted) {
            eventsAgain.interval = root.eventsBackoff;
            root.eventsBackoff = Math.min(60000, root.eventsBackoff * 2);
            eventsAgain.restart();
        }
    }
    Timer {
        id: eventsAgain
        onTriggered: events.running = root.watchWanted
    }
    // booting/installing: RDP readiness has no event. 15 s while it boots (60 s during the 30 min first install),
    // whether or not the panel is open: a lost «ready» must not keep the VM awake forever
    Timer {
        interval: root.installing ? 60000 : 15000
        repeat: true
        running: root.booting
        onTriggered: root.refresh()
    }

    // ── automatic pause / stop ──────────────────────────────────────────────────────────────
    readonly property bool shinobiPolicy: Modes.shinobi && (Settings.data.shinobi.funeStop ?? true)
    readonly property bool oniPolicy: Modes.oni && (Settings.data.oni.funePause ?? true)
    readonly property bool fastPolicy: shinobiPolicy || oniPolicy
    // the CLI said «not now» (exit 3): ask again only when something it looks at changes, or after 10 min
    property bool autoHeld: false
    readonly property string autoKey: [state, ready, windows, Modes.state, hold, setupDone].join("|")
    onAutoKeyChanged: autoHeld = false
    Timer {
        running: root.autoHeld
        interval: 600000
        onTriggered: root.autoHeld = false
    }
    // grace after opening an app: a cold first logon can take longer than the 8 s of Shinobi/Oni to map its window
    property bool launching: false
    function opened(): void {
        launching = true;
        launchGrace.restart();
    }
    Timer {
        id: launchGrace
        interval: 45000
        onTriggered: root.launching = false
    }
    onWindowsChanged: if (windows > 0) launching = false
    readonly property int pauseMs: Math.min(240, Math.max(1, cfg.pauseMinutes ?? 10)) * 60000
    readonly property int stopMs: Math.min(1440, Math.max(1, cfg.stopMinutes ?? 30)) * 60000
    readonly property bool wantPause: running && ready && setupDone && !hold && windows === 0 && !busy && !launching
                                      && !autoHeld && Niri.available && (cfg.autoPause || fastPolicy)
    Timer {
        running: root.wantPause
        interval: root.fastPolicy ? 8000 : root.pauseMs
        onTriggered: root.act(["pause", "--auto"])
    }
    // shutdown: counted from the real pause time (a shell restart does not reset it)
    readonly property bool wantStop: paused && !busy && !hold && !autoHeld && ((cfg.stopMinutes ?? 30) > 0 || shinobiPolicy)
    Timer {
        running: root.wantStop
        interval: {
            const full = root.shinobiPolicy ? 5 * 60000 : root.stopMs;
            const gone = root.pausedSince > 0 ? Date.now() - root.pausedSince : 0;
            return Math.max(5000, full - gone);
        }
        onTriggered: root.act(["stop", "--auto"])
    }

    // stats: one podman process streaming every 2 s while the panel shows them (never in Shinobi or while paused:
    // a paused VM uses 0 % by definition)
    readonly property bool statsWanted: statsUsers > 0 && running && !Modes.shinobi
    onStatsWantedChanged: {
        statsProc.running = statsWanted;
        if (!statsWanted)
            statsFresh = false;
    }
    onStatsUsersChanged: if (statsUsers > 0) { refresh(); refreshApps(); }
    Process {
        id: statsProc
        command: ["podman", "stats", "--interval", "2", "--no-reset", "--format", "{{.CPUPerc}}|{{.MemUsage}}", "WinApps"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|");
                if (parts.length < 2)
                    return;
                root.cpu = Math.min(1, (parseFloat(parts[0]) || 0) / 100 / Math.max(1, root.cores));
                root.mem = root.decimalBytes(parts[1].split("/")[0]);
                root.statsFresh = true;
            }
        }
    }
    // podman prints decimal units («6.596GB»), or binary ones with an «i»
    function decimalBytes(s: string): real {
        const m = /([\d.]+)\s*([kKMGT]?)(i?)B/.exec(s ?? "");
        if (!m)
            return 0;
        const base = m[3] === "i" ? 1024 : 1000;
        return parseFloat(m[1]) * Math.pow(base, " KMGT".indexOf(m[2].toUpperCase() || " "));
    }

    // the asagi ring follows the theme (Shinobi's theme has a darker one)
    readonly property string ringKey: Settings.ready ? String(Theme.colors.asagi) : ""
    onRingKeyChanged: if (ringKey !== "" && installed) rulesLater.restart()
    Timer {
        id: rulesLater
        interval: 800
        onTriggered: Quickshell.execDetached([root.cli, "rules", "--quiet"])
    }

    Component.onCompleted: {
        refresh();
        refreshApps();
        // «Arrancar con el cargador»: the CLI checks the setting, AC and a once-per-session marker itself (the
        // settings may not be loaded yet here)
        Quickshell.execDetached([cli, "login-start"]);
    }
}
