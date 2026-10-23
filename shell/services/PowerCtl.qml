pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Bridge to the root helper /usr/local/libexec/ocarina-powerctl (system/, polkit org.ocarinashell.powerctl: active
// local session, no password). Writes go through pkexec, one at a time and in order; `status` needs no root and is
// read on demand (start-up, Modes, after a write) — never polled. Without the helper installed everything here is a
// no-op and `available` stays false (Settei says how to install it).
// It also keeps the kernel's charge thresholds in line with Ajustes → Energía (debounced: a slider drag is one write).
Singleton {
    id: root

    readonly property string helper: "/usr/local/libexec/ocarina-powerctl"
    property bool available: false
    property var status: ({})             // last `status` JSON
    property string error: ""
    property var queue: []                // [{ args, done }]
    readonly property bool busy: writer.running || queue.length > 0

    // args: e.g. ["boost", "off"]; done(ok) is optional
    function run(args: var, done: var): void {
        if (!available) {
            if (done)
                done(false);
            return;
        }
        queue = queue.concat([{ args: args, done: done ?? null }]);
        if (!writer.running)
            next();
    }
    function next(): void {
        if (queue.length === 0) {
            readStatus();
            return;
        }
        const j = queue[0];
        queue = queue.slice(1);
        writer.job = j;
        writer.command = ["pkexec", helper].concat(j.args);
        writer.running = true;
    }
    function readStatus(): void {
        if (available && !reader.running)
            reader.running = true;
    }

    Process {
        id: writer
        property var job: null
        stderr: StdioCollector { id: writerErr }
        onExited: code => {
            const ok = code === 0;
            if (!ok) {
                root.error = writerErr.text.trim() || ("ocarina-powerctl " + writer.job.args.join(" ") + " → " + code);
                console.warn("PowerCtl:", root.error);
            }
            if (writer.job?.done)
                writer.job.done(ok);
            writer.job = null;
            root.next();
        }
    }
    Process {
        id: reader
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.syncCharge();
            }
        }
    }
    // installed? (once; Settei → Energía asks again after install-system.sh)
    function probe(): void {
        prober.running = true;
    }
    Process {
        id: prober
        running: true
        command: ["test", "-x", root.helper]
        onExited: code => {
            root.available = code === 0;
            if (root.available)
                root.readStatus();
        }
    }

    // ── charge limit: Settings → kernel ────────────────────────────────────────────────────────────
    readonly property var limit: Settings.data.power.chargeLimit
    readonly property string wantedCharge: {
        if (!limit.enabled)
            return "off";
        const end = Math.max(50, Math.min(100, Math.round(limit.end)));
        const start = Math.max(40, Math.min(95, Math.min(Math.round(limit.start), end - 5)));
        return start + " " + end;
    }
    onWantedChargeChanged: chargeLater.restart()
    Timer {
        id: chargeLater
        interval: 1200
        onTriggered: root.syncCharge()
    }
    function syncCharge(): void {
        const c = status.charge;
        if (!available || !Settings.ready || !c || c.end === null || c.end === undefined || chargeLater.running)
            return;
        const now = c.saved === "off" || (c.end === 100 && !c.saved) ? "off" : c.start + " " + c.end;
        if (now === wantedCharge && c.saved === wantedCharge)
            return;
        if (pendingCharge === wantedCharge || failedCharge === wantedCharge || doneCharge === wantedCharge)
            return;                       // in flight, refused once or already written: never a retry loop
        const w = wantedCharge;
        pendingCharge = w;
        run(w === "off" ? ["charge", "off"] : ["charge"].concat(w.split(" ")), ok => {
            root.pendingCharge = "";
            root.failedCharge = ok ? "" : w;
            root.doneCharge = ok ? w : "";  // if the firmware rounds it, we do not write again and again
        });
    }
    property string doneCharge: ""
    property string pendingCharge: ""
    property string failedCharge: ""
}
