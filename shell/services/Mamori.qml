pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 守 Mamori in the shell (fase 16, docs/06 capa 6): reads what bin/ocarina-mamori writes in
// ~/.local/state/ocarinashell/mamori/ (status, history, holds, health) for the 守 page, answers its `conditions`
// question over IPC (idle ≥ 10 min, locked, «Despierto», recording, Oni) and starts a cycle by itself when Ayoub has
// been away 15 min and one is due. Nothing is polled: the files are read when they change (the CLI also pings
// `mamori refresh`), relative times follow the shell's minute tick.
Singleton {
    id: root

    readonly property string dir: Paths.state + "/mamori"
    readonly property string cli: Paths.bin + "/ocarina-mamori"
    readonly property bool available: Tools.has("checkupdates")
    readonly property var cfg: Settings.data.mamori

    property var st: ({})
    property var health: ({})
    property var holds: ({})
    property var events: []                    // newest first
    property bool installed: false             // status.json exists: Mamori has run at least once
    // the minute tick drives every «now» below (hoy → ayer, expired holds and pauses)
    property real now: Date.now()
    Connections {
        target: Time
        function onMinuteTick(): void { root.now = Date.now(); }
    }

    // alive = it ran in the last 48 h; otherwise the bar keeps counting updates by itself (Updates)
    readonly property bool alive: installed && now - (st.updated ?? 0) * 1000 < 48 * 3600000
    readonly property bool paused: (st.pausedUntil ?? 0) * 1000 > now
    readonly property bool running: st.state === "running"
    readonly property bool active: cfg.enabled && !paused && alive
    readonly property var holdList: Object.keys(holds)
        .filter(k => holds[k] && typeof holds[k] === "object" && (Number(holds[k].until) || 0) * 1000 > now)
        .map(k => Object.assign({ name: k }, holds[k]))
    // what you have not seen yet: the last 7 days, after you last left Ajustes › 守 (a false alarm you already read,
    // or one fixed since, must not keep the badge up for a week — fase 17)
    readonly property real seenAt: cfg.seenAt ?? 0
    readonly property int attention: events.filter(e => (e.result === "attention" || e.result === "fail")
        && now - e.at * 1000 < 7 * 86400000 && e.at > seenAt).length
    function markSeen(): void {
        Settings.set("mamori.seenAt", Math.floor(Date.now() / 1000));
    }

    // ── the 守 card's text ──
    readonly property string headline: !cfg.enabled ? "Piloto automático apagado"
        : !installed ? "Aún sin revisar"
        : paused ? "En pausa"
        : running ? "Revisando…"
        : st.lastResult === "rolled-back" ? "Actualización revertida"
        : st.lastResult === "failed" ? "El último ciclo falló"
        : st.state === "waiting" ? "Esperando el momento"
        : (st.pending?.decision === "hold") ? "Lote retenido"
        : (st.pending?.decision === "mature") ? "Madurando actualizaciones"
        // one severity for the whole card: the headline, its tint and the chip say the same thing (visual QA, fase 17)
        : attention > 0 ? (attention === 1 ? "Una cosa para mirar" : attention + " cosas para mirar")
        : st.lastRun ? "Todo en orden" : "Aún sin revisar"
    readonly property string tone: !cfg.enabled || paused || !installed ? ""
        : st.lastResult === "failed" || st.lastResult === "rolled-back" ? "warn"
        : attention > 0 || st.pending?.decision === "hold" ? "hold" : "ok"
    readonly property string detail: {
        if (paused)
            return "Hasta el " + date(st.pausedUntil) + " · «Reanudar» o ocarina mamori resume";
        const parts = [];
        parts.push(st.lastRun ? "Última revisión " + when(st.lastRun) : "Nunca ha revisado todavía");
        if (st.state === "waiting" && st.deferReason)
            parts.push(st.deferReason);
        else if (st.nextRun)
            parts.push("próxima " + when(st.nextRun) + (cfg.batteryMin > 0 ? "" : " (con cargador)"));
        return parts.join(" · ");
    }

    function when(ts: real): string {
        if (!ts)
            return "—";
        const d = new Date(ts * 1000), today = new Date(now);
        const hm = Qt.formatTime(d, "HH:mm");
        const day = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime();
        const that = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        const diff = Math.round((that - day) / 86400000);
        if (diff === 0)
            return (ts * 1000 > now && d.getHours() < 7 ? "esta noche " : "hoy ") + hm;
        if (diff === -1)
            return "ayer " + hm;
        if (diff === 1)
            return d.getHours() < 7 ? "esta noche" : "mañana " + hm;
        return Qt.formatDate(d, "d MMM") + " " + hm;
    }
    function date(ts: real): string {
        return ts ? Qt.formatDate(new Date(ts * 1000), "d MMM") : "—";
    }
    // timeline: the time today, «ayer», or the date
    function stamp(ts: real): string {
        const d = new Date(ts * 1000), today = new Date(now);
        if (d.toDateString() === today.toDateString())
            return Qt.formatTime(d, "HH:mm");
        if (new Date(now - 86400000).toDateString() === d.toDateString())
            return "ayer";
        return Qt.formatDate(d, "d MMM");
    }

    function reload(): void {
        statusFile.reload();
        historyFile.reload();
        holdsFile.reload();
        healthFile.reload();
    }
    function cmd(args: var): void {
        Quickshell.execDetached([cli].concat(args));
    }
    function runNow(): void {
        Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "ocarina-mamori.service"]);
    }
    function pause(days: real): void { cmd(["pause", String(days)]); }
    function resume(): void { cmd(["resume"]); }
    function unhold(pkg: string): void { cmd(["unhold", pkg]); }
    // undo asks for confirmation in a terminal: it changes the whole system
    function undo(): void {
        if (Tools.has("ghostty"))
            Quickshell.execDetached(["ghostty", "+new-window", "--title=守 Deshacer la última actualización", "-e",
                                     Paths.bin + "/ocarina", "mamori", "rollback"]);
    }
    // the week's summary: opened if it exists, written quietly (no commit, no notification) if not
    function weekly(): void {
        if (!weeklyProc.running)
            weeklyProc.running = true;
    }
    readonly property bool weeklyBusy: weeklyProc.running

    // only what changed is applied: an identical file never rebuilds the page's lists
    property string _st: ""
    property string _hist: ""
    property string _holds: ""
    property string _health: ""
    function parseHistory(text: string): void {
        const lines = text.split("\n").filter(l => l.trim() !== "").slice(-80);
        const out = [];
        for (let i = lines.length - 1; i >= 0; i--) {
            try {
                const e = JSON.parse(lines[i]);
                if (e && typeof e.at === "number" && e.kind !== "info")
                    out.push({ at: e.at, kind: String(e.kind ?? ""), result: String(e.result ?? ""),
                               title: String(e.title ?? ""), detail: String(e.detail ?? "") });
            } catch (err) {}
        }
        events = out;
    }
    function json(text: string, fallback: var): var {
        try {
            const v = JSON.parse(text);
            return v && typeof v === "object" ? v : fallback;
        } catch (e) {
            return fallback;
        }
    }

    FileView {
        id: statusFile
        path: root.dir + "/status.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.installed = true;
            const t = text();
            if (t !== root._st) {
                root._st = t;
                root.st = root.json(t, {});
            }
        }
        onLoadFailed: {
            root.installed = false;
            root._st = "";
            root.st = {};
        }
    }
    FileView {
        id: historyFile
        path: root.dir + "/history.jsonl"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (t !== root._hist) {
                root._hist = t;
                root.parseHistory(t);
            }
        }
        onLoadFailed: {
            root._hist = "";
            root.events = [];
        }
    }
    FileView {
        id: holdsFile
        path: root.dir + "/holds.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (t !== root._holds) {
                root._holds = t;
                root.holds = root.json(t, {});
            }
        }
        onLoadFailed: {
            root._holds = "";
            root.holds = {};
        }
    }
    FileView {
        id: healthFile
        path: root.dir + "/health.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (t !== root._health) {
                root._health = t;
                root.health = root.json(t, {});
            }
        }
        onLoadFailed: {
            root._health = "";
            root.health = {};
        }
    }
    Process {
        id: weeklyProc
        command: [root.cli, "report", "--weekly", "--quiet"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/:\s*(\S+\.md)\s*$/m);
                const notes = Paths.repo + "/docs/mantenimiento/";
                if (m && m[1].startsWith(notes) && m[1].indexOf("..") < 0)
                    Quickshell.execDetached(["xdg-open", m[1]]);
            }
        }
    }

    // ── opportunistic cycle: 15 min away (inhibitors ignored), one due or the last over 20 h ago, on AC ──
    Connections {
        target: Idle
        function onLongIdleChanged(): void {
            if (!Idle.longIdle)
                return;
            root.reload();
            opportunity.restart();
        }
    }
    Timer {
        id: opportunity
        interval: 2000
        onTriggered: {
            if (!root.available || !root.cfg.enabled || root.paused || root.running
                    || Power.onBattery && root.cfg.batteryMin <= 0)
                return;
            const stale = Date.now() - (root.st.lastRun ?? 0) * 1000 > 20 * 3600000;
            if (root.st.due || stale || root.st.restartPending)
                Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "ocarina-mamori@shell.service"]);
        }
    }

    // IPC `mamori conditions`: what only the shell knows
    function conditions(): string {
        return JSON.stringify({ idle10: Idle.idle10, longIdle: Idle.longIdle, locked: Lock.locked,
                                inhibit: Idle.inhibit, recording: Recorder.recording, oni: Modes.oni });
    }
    function status(): string {
        return JSON.stringify({ headline: headline, detail: detail, paused: paused, running: running, alive: alive,
                                holds: holdList.length, attention: attention, lastRun: st.lastRun ?? 0 });
    }
}
