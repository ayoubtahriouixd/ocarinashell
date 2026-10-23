pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 録 Screen recording with wf-recorder (wlr-screencopy) on the focused output or a slurp region, saved to
// ~/Vídeos/Grabaciones. Runs as the transient unit ocarina-rec (systemd-run): a shell reload or restart never
// kills it (an mp4 cut by SIGTERM is broken). Stop = SIGINT, which makes wf-recorder finalise the file.
Singleton {
    id: root

    property bool recording: false
    property double startedAt: 0
    property string file: ""
    property string error: ""

    function toggle(): void {
        recording ? stop() : start(false);
    }
    function start(region: bool): void {
        if (recording || launcher.running)
            return;
        Panels.close();
        const dir = (Quickshell.env("HOME") ?? "") + "/Vídeos/Grabaciones";
        file = dir + "/Grabación " + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        launcher.command = ["sh", "-c",
            'command -v wf-recorder >/dev/null || exit 4; mkdir -p "$1"; '
            + (region ? 'command -v slurp >/dev/null || exit 4; g=$(slurp -d </dev/null) || exit 2; set -- "$@" -g "$g"; '
                      : 'set -- "$@" -o "$3"; ')
            + 'f="$2"; shift 3; exec systemd-run --user --quiet --collect --unit=ocarina-rec wf-recorder "$@" -f "$f"',
            "sh", dir, file, Niri.focusedOutput];
        launcher.running = true;
    }
    function stop(): void {
        if (recording)
            Quickshell.execDetached(["systemctl", "--user", "kill", "-s", "INT", "ocarina-rec.service"]);
        watch.running = true;
    }

    Process {
        id: launcher
        onExited: code => {
            if (code === 0) {
                root.recording = true;
                root.startedAt = Date.now();
                state.setText(JSON.stringify({ file: root.file, startedAt: root.startedAt }) + "\n");
                Osd.show("info", 0, "Grabando la pantalla · 録", "screen_record");
            } else if (code === 4) {
                root.error = "falta wf-recorder o slurp";
                Osd.show("info", 0, "No se puede grabar: " + root.error, "error");
            } else if (code !== 2) {          // 2 = region selection cancelled
                root.error = "systemd-run falló (" + code + ")";
                Osd.show("info", 0, "No se pudo empezar a grabar", "error");
            }
        }
    }
    // waits for the unit to end after SIGINT, then reports
    Process {
        id: watch
        command: ["sh", "-c", "for i in $(seq 100); do systemctl --user -q is-active ocarina-rec.service || exit 0; sleep 0.1; done; exit 1"]
        onExited: code => {
            root.recording = false;
            state.setText("{}\n");
            Quickshell.execDetached(["sh", "-c", '[ -s "$1" ] && notify-send -a OcarinaShell -i video-x-generic "Grabación guardada" "$1" || notify-send -a OcarinaShell "La grabación no se guardó"', "sh", root.file]);
        }
    }
    // after a reload: is a recording still running?
    Process {
        id: probe
        command: ["systemctl", "--user", "-q", "is-active", "ocarina-rec.service"]
        running: true
        onExited: code => root.recording = code === 0
    }
    FileView {
        id: state
        atomicWrites: true
        path: Paths.state + "/recording.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.file) {
                    root.file = d.file;
                    root.startedAt = d.startedAt;
                }
            } catch (e) {}
        }
    }
}
