pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 読 Yomu — read and translate what you see (fase 15, docs/07-IDEAS.md; Mod+Alt+T, `ocarina read [--translate]`).
// bin/ocarina-read: slurp → grim → local tesseract (Japanese horizontal/vertical, Spanish, English) → JSON; the text
// goes to the clipboard and a small card (Panels "yomu") opens next to the region. «Traducir» runs the Snake task
// `translate` (Spanish + hiragana + rōmaji, validated JSON), loading Snake on demand under its RAM policy. Nothing
// leaves the machine; the capture (in $XDG_RUNTIME_DIR) is deleted when the card closes.
Singleton {
    id: root

    property bool capturing: false          // selection + grim + OCR: the software-dim layer hides meanwhile (D-009)
    property bool reading: false
    property var result: null               // { text, vertical, japanese, confidence, geometry, ms }
    property string error: ""
    // the region in global logical coordinates, for placing the card next to it
    property real gx: 0
    property real gy: 0
    property real gw: 0
    property real gh: 0
    // translation
    property var translation: null          // { translation_es, reading_hiragana, romaji, notes }
    property bool translating: trProc.running
    property string trError: ""
    property string trPartial: ""           // the translation as it is written (streamed)
    property bool wantTranslate: false
    property bool restartPending: false

    function region(translate: bool): void {
        // a selection left hanging (slurp lost its surface, e.g. on an output modeset) must not swallow the shortcut:
        // pressing it again cancels that one and starts afresh
        if (capturing && !reading) {
            if (capProc.running) {
                restartPending = true;
                wantTranslate = translate;
                capProc.signal(15);
            }
            return;
        }
        if (reading)
            return;
        if (!Settings.data.extras.yomu) {
            Osd.show("info", 0, "読 Yomu está desactivado en Ajustes → Atajos", "translate");
            return;
        }
        Panels.close();
        result = null;
        translation = null;
        error = "";
        trError = "";
        wantTranslate = translate;
        capturing = true;
        // one frame for the dim layer and the panel to leave the screen before slurp freezes it
        Qt.callLater(() => capProc.running = true);
    }
    function translate(): void {
        if (!result?.text || trProc.running)
            return;
        trError = "";
        translation = null;
        trPartial = "";
        trProc.running = true;
    }
    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text]);
        Osd.show("info", 0, "Texto copiado", "content_copy");
    }
    // the card closed: the capture is deleted, nothing is kept
    function closed(): void {
        if (capturing || reading)
            return;                                       // a new reading already began: not ours to clear
        if (trProc.running)
            trProc.signal(15);
        result = null;
        translation = null;
        Quickshell.execDetached([Paths.bin + "/ocarina-read", "clean"]);
    }
    function status(): string {
        return JSON.stringify({ reading: reading, text: result?.text ?? "", vertical: result?.vertical ?? false,
                                confidence: result?.confidence ?? 0, translating: translating,
                                translation: translation?.translation_es ?? "", error: error || trError });
    }
    // tests: OCR a file without slurp (IPC `yomu file <png>`)
    function file(path: string): void {
        Panels.close();
        result = null;
        translation = null;
        capProc.command = [Paths.bin + "/ocarina-read", "ocr", path];
        reading = true;
        capProc.running = true;
    }

    Process {
        id: capProc
        command: [Paths.bin + "/ocarina-read", "capture"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try {
                    d = JSON.parse(text);
                } catch (e) {}
                if (!d)
                    return;
                if (d.error) {
                    root.error = d.error;
                    return;
                }
                root.result = d;
                const m = /^(-?\d+),(-?\d+) (\d+)x(\d+)$/.exec(d.geometry ?? "");
                if (m) {
                    root.gx = +m[1]; root.gy = +m[2]; root.gw = +m[3]; root.gh = +m[4];
                } else {
                    root.gx = 0; root.gy = 0; root.gw = 0; root.gh = 0;
                }
                if (d.text)
                    root.copy(d.text);
            }
        }
        onExited: code => {
            root.capturing = false;
            root.reading = false;
            capProc.command = [Paths.bin + "/ocarina-read", "capture"];
            if (root.restartPending) {
                root.restartPending = false;
                root.region(root.wantTranslate);
                return;
            }
            if (code === 2)
                return;                                   // Esc in slurp: nothing to show
            if (code === 3)
                root.error = "No he encontrado texto en esa zona.";
            else if (code === 4)
                root.error = "Falta tesseract, grim o slurp.";
            else if (!root.result && root.error === "")
                root.error = "No se pudo leer (código " + code + ").";
            Panels.show("yomu", "");
            if (root.wantTranslate && root.result?.text)
                root.translate();
        }
    }
    Process {
        id: trProc
        command: [Paths.bin + "/ocarina-snake", "translate", "--stream", "-"]
        stdinEnabled: true
        onRunningChanged: if (running) {
            write(root.result?.text ?? "");
            stdinEnabled = false;                         // EOF
        }
        // one JSON per line: {"delta"} while the translation is written, then the result
        stdout: SplitParser {
            onRead: line => {
                let d = null;
                try {
                    d = JSON.parse(line);
                } catch (e) {}
                if (typeof d?.delta === "string")
                    root.trPartial += d.delta;
                else if (d?.ok && d.result) {
                    root.trPartial = "";
                    root.translation = d.result;
                }
                else if (d?.ok === false && d.reason)
                    root.trError = "Snake no puede cargarse ahora: " + d.reason + ".";
                else if (d?.errors)
                    root.trError = "La traducción no fue válida; prueba otra vez.";
            }
        }
        onExited: code => {
            stdinEnabled = true;
            if (code !== 0 && root.trError === "" && root.translation === null)
                root.trError = "Snake no pudo traducir (código " + code + ").";
        }
    }
}
