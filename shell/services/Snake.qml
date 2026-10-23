pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 蛇 Snake — the local AI (docs/01-ARQUITECTURA §18, fase 15). bin/ocarina-snake does the work (server on 127.0.0.1,
// loaded on demand, unloaded after snake.keepAliveMin); the shell shows it and talks to it:
// - state: `ocarina-snake status --json` at start and whenever the CLI says «loaded» / «unloaded» over IPC: no polling;
// - the assistant (Panels "snake", mockup 11): `ocarina-snake assist --stream` per question, its answer streamed line
//   by line; a proposed action is only an id of snake/actions.json, run with `run-action <id> --confirmed` when the
//   user presses «Ejecutar»;
// - 声 voice: `ocarina-snake listen` records until a pause and transcribes locally (whisper.cpp); its text is asked
//   like a typed question. The audio never leaves RAM. The mic button, Mod+Alt+A or `ocarina snake listen`;
// - 忍 Shinobi and 鬼 Oni unload it at once (the server also checks by itself every 5 s).
Singleton {
    id: root

    readonly property string cli: Paths.bin + "/ocarina-snake"
    readonly property var cfg: Settings.data.snake

    // ── state ───────────────────────────────────────────────────────────────────────────────
    property bool checked: false
    property bool loaded: false
    property bool starting: false
    property string model: ""
    property string name: ""
    property string backend: "vulkan"
    property bool canLoad: true
    property string policy: ""
    property bool modelPresent: true
    property real tps: 0                     // generation speed of the last answer
    readonly property bool available: checked && cfg.enabled
    readonly property bool shown: loaded || starting || busy     // the 蛇 indicator in Obi

    // ── conversation ────────────────────────────────────────────────────────────────────────
    // [{ role: "user"|"assistant"|"note", text, attach: [..], action: {id, argv, label, detail, reason}|null }]
    property var messages: []
    // each action's progress, by message index, kept apart: changing it must not replace `messages` (that would
    // rebuild the list and jump to the top). { "<index>": { state: running|done|failed|cancelled, output } }
    property var actionStates: ({})
    property bool busy: askProc.running
    property string streaming: ""            // the answer being written
    property var attach: []                  // chips chosen for the next question
    readonly property var attachKinds: [
        { id: "journal", label: "journal · 12 h", icon: "receipt_long" },
        { id: "net", label: "red", icon: "network_wifi" },
        { id: "mamori", label: "Mamori", icon: "history" },
        { id: "shinobi", label: "Shinobi", kanji: "忍" },
        { id: "clipboard", label: "portapapeles", icon: "content_paste" },
        { id: "window", label: "ventana", icon: "select_window" }
    ]

    // ── 声 voice ────────────────────────────────────────────────────────────────────────────
    property bool listening: false           // recording (the level moves)
    property bool transcribing: false
    property real level: 0                   // 0–1, ~12 frames per second while listening
    readonly property bool voiceBusy: listenProc.running
    function listen(): void {
        if (listenProc.running) {
            listenProc.signal(15);           // «stop»: transcribe what was said so far
            return;
        }
        if (busy) {
            Osd.show("info", 0, "Snake aún está respondiendo", "hourglass_top");
            return;
        }
        if (!cfg.enabled) {
            note("Snake está desactivado en Ajustes › 蛇 Snake.");
            return;
        }
        level = 0;
        listenProc.running = true;
    }
    function cancelListen(): void {
        if (listenProc.running)
            listenProc.signal(10);           // SIGUSR1: drop the audio, no transcription
    }
    Process {
        id: listenProc
        command: [root.cli, "listen"]
        stdout: SplitParser {
            onRead: line => {
                let d = null;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (d.level !== undefined) {
                    root.level = d.level;
                } else if (d.state === "listening") {
                    root.listening = true;
                } else if (d.state === "transcribing") {
                    root.listening = false;
                    root.transcribing = true;
                } else if (d.text !== undefined) {
                    root.transcribing = false;
                    if (d.text !== "")
                        root.ask(d.text);
                    else
                        Osd.show("info", 0, "No te he oído", "mic_off");
                } else if (d.ok === false && d.reason) {
                    root.note("Ahora no: " + d.reason + ".");
                }
            }
        }
        stderr: StdioCollector {
            id: listenErr
        }
        onExited: code => {
            root.listening = false;
            root.transcribing = false;
            root.level = 0;
            if (code !== 0 && code !== 5 && code !== 143 && code !== 15) {
                const why = listenErr.text.replace(/^ocarina-snake: /, "").trim().split("\n").pop();
                root.note("La voz no funcionó: " + (why || "código " + code) + ".");
            }
        }
    }

    // the catalogue (snake/models.json) with what is downloaded: Ajustes › 蛇 Snake asks for it when it opens
    property var models: []
    function loadModels(): void {
        if (!modelsProc.running)
            modelsProc.running = true;
    }
    // «Probar ahora»: the assistant with a tiny question (loads the model, shows the cold start)
    function test(): void {
        Panels.show("snake", "");
        ask("Hola, preséntate en una frase y dime qué modelo eres.");
    }

    function toggle(): void { Panels.toggle("snake", ""); }
    // the panel opened: start loading while the question is typed (the CLI only does it on AC, policy permitting)
    function warm(): void {
        if (cfg.enabled && !loaded && !starting && !busy && !Modes.shinobi && !Modes.oni && Modes.phase !== "entering"
            && !Power.onBattery && modelPresent && canLoad && !warmProc.running)
            warmProc.running = true;
    }
    property bool refreshAgain: false
    function refresh(): void {
        if (statusProc.running)
            refreshAgain = true;          // a «loaded»/«unloaded» while one is reading: read again after it
        else
            statusProc.running = true;
    }
    function stop(): void {
        Quickshell.execDetached([cli, "stop"]);
    }
    function toggleAttach(kind: string): void {
        attach = attach.indexOf(kind) >= 0 ? attach.filter(k => k !== kind) : attach.concat([kind]);
    }
    function clear(): void {
        if (!busy && !actProc.running) {
            messages = [];
            actionStates = {};
        }
    }

    // true when the question was taken (the field empties only then)
    function ask(text: string): bool {
        const q = text.trim();
        if (q === "")
            return false;
        if (busy) {
            Osd.show("info", 0, "Snake aún está respondiendo", "hourglass_top");
            return false;
        }
        if (!cfg.enabled) {
            note("Snake está desactivado en Ajustes › 蛇 Snake.");
            return true;
        }
        const turn = { role: "user", text: q, attach: attach.slice(), action: null };
        // the last turns go to the CLI as history (RAM: $XDG_RUNTIME_DIR)
        history.setText(JSON.stringify(messages.filter(m => m.role !== "note").slice(-6)
                                       .map(m => ({ role: m.role, content: m.text }))));
        messages = messages.concat([turn]);
        let argv = [cli, "assist", "--stream", "--history", history.path];
        for (const a of attach)
            argv = argv.concat(["--attach", a]);
        askProc.command = argv.concat(["--", q]);
        attach = [];
        streaming = "";
        if (!loaded)
            starting = true;
        cancelled = false;
        askProc.running = true;
        return true;
    }
    property bool cancelled: false
    function cancel(): void {
        if (askProc.running) {
            cancelled = true;
            askProc.signal(15);
        }
    }
    function note(text: string): void {
        messages = messages.concat([{ role: "note", text: text, attach: [], action: null }]);
    }
    // «Ejecutar» on a proposed action: runs only ids of the whitelist, through the CLI that checks it again
    function actionState(index: int): string {
        return actionStates[String(index)]?.state ?? "";
    }
    function runAction(index: int): void {
        const m = messages[index];
        if (!m?.action || actionState(index) !== "" || actProc.running)
            return;
        setState(index, "running", "");
        actProc.index = index;
        actProc.command = [cli, "run-action", m.action.id, "--confirmed"];
        actProc.running = true;
    }
    function dismissAction(index: int): void {
        if (messages[index]?.action && actionState(index) === "")
            setState(index, "cancelled", "");
    }
    function setState(index: int, s: string, output: string): void {
        if (index < 0 || index >= messages.length)
            return;
        const copy = Object.assign({}, actionStates);
        copy[String(index)] = { state: s, output: output };
        actionStates = copy;
    }
    function status(): string {
        return JSON.stringify({ loaded: loaded, starting: starting, model: model, backend: backend, busy: busy,
                                canLoad: canLoad, policy: policy, messages: messages.length });
    }
    // from bin/ocarina-snake (IPC)
    function onLoaded(n: string): void {
        loaded = true;
        starting = false;
        if (n !== "")
            name = n;
        refresh();
    }
    function onUnloaded(): void {
        loaded = false;
        starting = false;
        refresh();
    }

    // ── processes ───────────────────────────────────────────────────────────────────────────
    Process {
        id: warmProc
        command: [root.cli, "warm"]
        onRunningChanged: if (running) root.starting = true
        onExited: {
            root.starting = false;            // status puts it back if the unit is still loading
            root.refresh();
        }
    }
    Process {
        id: statusProc
        command: [root.cli, "status", "--json"]
        onExited: if (root.refreshAgain) { root.refreshAgain = false; running = true; }
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try {
                    d = JSON.parse(text);
                } catch (e) {}
                root.checked = true;
                if (!d)
                    return;
                // every field optional: an older or newer CLI must not break the rest (docs/06 capa 3)
                root.loaded = d.loaded === true;
                root.starting = d.starting === true || (root.starting && (root.busy || warmProc.running));
                root.model = String(d.model ?? "");
                root.name = String(d.name ?? "");
                root.backend = String(d.backend ?? "vulkan");
                root.canLoad = d.canLoad !== false;
                root.policy = String(d.policy ?? "");
                root.modelPresent = d.modelPresent !== false;
                if (!root.tps)
                    root.tps = Number(d.tps) || 0;
            }
        }
    }
    Process {
        id: modelsProc
        command: [root.cli, "models", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.models = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Process {
        id: askProc
        stdout: SplitParser {
            onRead: line => {
                let d = null;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (d.delta !== undefined) {
                    root.starting = false;
                    root.streaming += d.delta;
                } else if (d.done) {
                    const r = d.result ?? {};
                    // an answer that found manipulation in its data proposes nothing: the action may come from it
                    const sus = r.suspicious === true;
                    const act = !sus && r.action && r.action.id && r.action.id !== "none" ? r.action : null;
                    root.messages = root.messages.concat([{ role: "assistant",
                        text: d.ok ? String(r.answer ?? "") : "No he podido darte una respuesta válida. Prueba otra vez.",
                        attach: [], action: act, suspicious: sus }]);
                    root.streaming = "";
                    if (d.meta?.gen_tps)
                        root.tps = d.meta.gen_tps;
                } else if (d.ok === false && d.reason) {
                    root.note("Ahora no: " + d.reason + ".");     // the policy said no (exit 5)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("Snake:", text.trim())
        }
        onExited: (code, status) => {
            root.starting = false;
            if (root.streaming !== "") {            // cut while writing (cancel): keep what arrived
                root.messages = root.messages.concat([{ role: "assistant", text: root.streaming + " …", attach: [],
                                                        action: null }]);
                root.streaming = "";
            }
            if (code !== 0 && code !== 5 && code !== 6 && !root.cancelled)
                root.note("Snake no pudo responder (código " + code + "). Mira journalctl -t ocarina-snake.");
            root.cancelled = false;
            root.refresh();
        }
    }
    Process {
        id: actProc
        property int index: -1
        stdout: StdioCollector {
            id: actOut
        }
        onExited: code => {
            let out = "";
            try {
                out = String(JSON.parse(actOut.text).out ?? "");
            } catch (e) {}
            // the read-only reports (doctor, smoke, update --check) are the point: keep their last lines
            root.setState(actProc.index, code === 0 ? "done" : "failed", out.split("\n").slice(-8).join("\n"));
            Osd.show("info", 0, code === 0 ? "Hecho" : "La acción falló", code === 0 ? "check" : "error");
        }
    }
    FileView {
        id: history
        path: Paths.runtime + "/snake-chat.json"
        printErrors: false
        atomicWrites: true
        blockWrites: true                 // tiny file in tmpfs: written before the CLI that reads it starts
    }

    // 忍 Shinobi / 鬼 Oni: never loaded there
    Connections {
        target: Modes
        // also while it loads or answers: cancel the question and unload
        function onShinobiChanged() { if (Modes.shinobi) root.leave(); }
        function onOniChanged() { if (Modes.oni) root.leave(); }
    }
    function leave(): void {
        cancel();
        cancelListen();
        if (warmProc.running)
            warmProc.signal(15);
        if (loaded || starting)
            stop();
    }
    Component.onCompleted: refresh()
}
