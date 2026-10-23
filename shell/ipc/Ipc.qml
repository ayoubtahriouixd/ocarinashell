pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Every IPC target of docs/01-ARQUITECTURA §6: `qs -c ocarina ipc call <target> <function> [args]`.
// Modules that do not exist yet answer "pendiente (fase N)"; the `ocarina` CLI treats that as "not handled" and
// uses its fallback (e.g. swaylock for the lock). NOTE: `qs ipc` exits 0 even on errors — the CLI checks the text.
Scope {
    id: root

    readonly property string version: Paths.version
    function pending(phase: int): string {
        return "pendiente (fase " + phase + ")";
    }

    IpcHandler {
        target: "shell"
        function version(): string { return root.version; }
        function reload(): string {
            if (Lock.active)
                return "bloqueado: la recarga espera al desbloqueo";
            Quickshell.reload(true);
            return "ok";
        }
        function status(): string {
            return JSON.stringify({ version: root.version, theme: Theme.id, mode: Modes.state, niri: Niri.available,
                                    failures: Health.failures });
        }
    }

    IpcHandler {
        target: "audio"
        function increment(step: string): void { Audio.increment(step); }
        function decrement(step: string): void { Audio.decrement(step); }
        function mute(): void { Audio.toggleMute(); }
        function micmute(): void { Audio.toggleMic(); }
        function set(pct: int): void { Audio.setVolume(pct / 100); }
        function status(): string {
            return JSON.stringify({ available: Audio.available, volume: Math.round(Audio.volume * 100), muted: Audio.muted,
                                    sink: Audio.sinkName, error: Audio.error });
        }
    }

    IpcHandler {
        target: "media"
        function playPause(): void { Media.playPause(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
        function stop(): void { Media.stop(); }
        function increment(step: string): void { Media.changeVolume(Math.abs(parseFloat(step) || 0.03)); }
        function decrement(step: string): void { Media.changeVolume(-Math.abs(parseFloat(step) || 0.03)); }
    }

    IpcHandler {
        target: "brightness"
        function increment(step: string, output: string): void { Brightness.increment(step, output); }
        function decrement(step: string, output: string): void { Brightness.decrement(step, output); }
        function set(pct: int, output: string): void { Brightness.set(pct, output); }
        function list(): string { return Brightness.list(); }
    }

    IpcHandler {
        target: "kbdlight"
        function cycle(): void { KbdLight.cycle(); }
        function set(level: int): void { KbdLight.set(level); }
    }

    IpcHandler {
        target: "lock"
        function lock(): string { Lock.lock(); return "ok"; }
        function isLocked(): bool { return Lock.locked; }   // on screen and not dissolving
        function test(): string { return Lock.startTest(); }
        function state(): string {
            return JSON.stringify({ active: Lock.active, test: Lock.test, secure: Lock.secure, locked: Lock.locked,
                                    fallback: Lock.fallback, unlocking: Lock.unlocking, checking: Lock.checking,
                                    failures: Lock.failures, wait: Lock.waitSeconds(), message: Lock.message,
                                    fingerprint: Lock.fingerprint, screenOff: Lock.screenOff });
        }
        // test mode only: a fixed WRONG password (never a real secret on a command line) and the Esc exit
        function submitWrong(): string {
            if (!Lock.active || !Lock.test)
                return "solo en modo prueba";
            return Lock.submit("\u0001ocarina-prueba-errónea\u0001") ? "comprobando" : "rechazado";
        }
        function cancel(): string { Lock.leaveTest(); return Lock.active ? "sigue activo" : "ok"; }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { Launcher.toggle(); }
        function open(mode: string, query: string): void { Launcher.show(mode, query); }
        function stats(): string {
            return JSON.stringify({ apps: Launcher.apps.length, lastFilterMs: Launcher.lastFilterMs, lastOpenMs: Launcher.lastOpenMs });
        }
        function bench(query: string, runs: int): string { return Launcher.bench(query, runs); }
        // current results (group · title · subtitle), for tests
        function results(): string {
            return Launcher.results.map(r => r.group + " · " + r.title + (r.subtitle ? " · " + r.subtitle : "")).join("\n");
        }
    }
    IpcHandler {
        target: "engawa"
        function toggle(): void { Panels.toggle("engawa", ""); }
        function open(page: string): void { Panels.show("engawa", page); }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { Panels.toggle("notifications", ""); }
        function dnd(state: string): void { Notifs.setDnd(state); }
        function clear(): void { Notifs.clearHistory(); }
    }
    IpcHandler {
        target: "island"
        function hover(on: bool): void { Panels.islandHoverTest = on; }
    }
    IpcHandler {
        target: "hiroba"
        function toggle(): void { Panels.toggle("hiroba", ""); }
        function open(): void { Panels.show("hiroba", ""); }
        function close(): void { if (Panels.open === "hiroba") Panels.close(); }
        function isOpen(): bool { return Panels.open === "hiroba"; }
    }
    IpcHandler {
        target: "koyomi"
        // 広場 Hiroba replaced Koyomi (the calendar lives inside it)
        function toggle(): void { Panels.toggle("hiroba", ""); }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { Dengen.toggle(); }
        function close(): void { Dengen.close(); }
        // tests/captures: select a card and draw its hold fill without running anything
        function select(i: int): void { Dengen.selected = Math.max(0, Math.min(4, i)); }
        function preview(progress: real): void { Dengen.previewHold = progress; }
        // さようなら test: shutdown | reboot | logout — the overlay only (nothing runs), 4 s or Esc
        function farewell(kind: string): void { Dengen.testFarewell(kind); }
        function isOpen(): bool { return Dengen.open; }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { Settei.toggle(); }
        function open(page: string): void { Settei.show(page); }
        function focusOrToggle(): void { Settei.toggle(); }
        function close(): void { Settei.close(); }
        function page(): string { return Settei.open ? Settei.page : ""; }
        // tests: search like typing in the field, and the results shown
        function search(text: string): void { Settei.show(""); Settei.query = text; }
        // tests: what clicking a search result does (go to the page and flash the row)
        function reveal(page: string, title: string): void { Settei.show(""); Settei.goTo(page, title); }
        // tests: values derived live from Settings by the singletons
        function live(): string {
            return JSON.stringify({ motionEnabled: Motion.enabled, motionScale: Motion.scale, radiusPanel: Theme.radius.panel,
                                    fontScale: Theme.font.scale, uiFont: Theme.font.ui, clock: Time.hhmm, dnd: Notifs.dnd,
                                    timeoutMs: Notifs.timeoutMs, rotating: Wallpapers.rotating, primary: Displays.primary,
                                    lowBattery: Power.low, curve: Brightness.curveOn, autoTheme: ThemeCtl.autoOn,
                                    overridesError: NiriConf.error });
        }
        // tests (persistence checklist): the same Settings.set the controls use; value as JSON
        function get(path: string): string { return JSON.stringify(Settings.get(path, null)); }
        function set(path: string, json: string): string {
            try {
                Settings.set(path, JSON.parse(json));
                return "ok";
            } catch (e) {
                return "JSON no válido";
            }
        }
    }
    IpcHandler {
        target: "techo"
        function toggle(): void { Panels.toggle("techo", ""); }
        function append(text: string): void { Notes.append(text); }
        function current(): string { return Notes.current; }
        function create(): void { Notes.create(); }
        function trash(): void { Notes.trash(Notes.current); }
        // as if typed at the end of the open note: goes through the debounced autosave (tests)
        function type(text: string): void { Notes.edit(Notes.text + text); }
    }
    IpcHandler {
        target: "kura"
        function toggle(): void { Panels.toggle("kura", ""); }
        function count(): int { return Clipboard.items.length; }
        function pin(id: int): string {
            const it = Clipboard.items.find(i => i.id === id);
            if (!it)
                return "no existe";
            Clipboard.pin(it);
            return "ok";
        }
        function pins(): string { return JSON.stringify(Clipboard.pins.map(p => p.kind + ":" + (p.kind === "text" ? p.text.length + " car." : p.meta))); }
    }
    IpcHandler { target: "mihari"; function toggle(): void { Panels.toggle("mihari", ""); } }
    IpcHandler { target: "mado"; function toggle(): void { Panels.toggle("mado", ""); } }
    IpcHandler { target: "cheatsheet"; function toggle(): void { Panels.toggle("cheatsheet", ""); } }
    IpcHandler {
        target: "workspace"
        function rename(): void { Panels.startRename(-1); }
        function cancel(): void { Panels.endRename(null); }
        // {"id": workspace being renamed or -1, "draft": field text} — tests check this before typing anything
        function editing(): string { return JSON.stringify({ id: Panels.renameId, draft: Panels.renameDraft }); }
    }

    IpcHandler {
        target: "kabegami"
        function browse(): void { Settei.show("fondos"); }
        function set(path: string): void { Settings.set("wallpaper.path", path); }
        function next(): void { Wallpapers.next(); }
        function count(): int { return Wallpapers.items.length; }
        function indexMs(): int { return Math.round(Wallpapers.indexMs); }
    }

    IpcHandler {
        target: "shinobi"
        function on(): string { return Modes.on("manual"); }
        function off(): string { return Modes.off("manual"); }
        function toggle(): string { return Modes.toggle("manual"); }
        function status(): string { return Modes.status(); }
    }
    IpcHandler {
        target: "oni"
        function on(): string { return Modes.oniOn("manual"); }
        function off(): string { return Modes.oniOff("manual"); }
        function toggle(): string { return Modes.oniToggle("manual"); }
        function status(): string { return Modes.status(); }
        function autoOn(): string { return Modes.autoOn(); }
        function autoOff(): string { return Modes.autoOff(); }
    }
    IpcHandler {
        target: "nameraka"
        function toggle(): void { Nameraka.toggle(); }
        function on(): void { if (!Nameraka.wanted) Nameraka.turnOn(); }
        function off(): void { if (Nameraka.wanted) Nameraka.off(); }
        function mode(m: string): void { Nameraka.setMode(m); }
        function fps(n: int): void { Nameraka.setFps(n); }
        function engine(e: string): string { return e === "ia" ? "IA no disponible (puerta de la fase 11)" : "lsfg"; }
        function calibrate(): void { Nameraka.calibrate(); }
        function status(): string { return Nameraka.status(); }
    }
    IpcHandler {
        target: "fune"
        function toggle(): void { Panels.toggle("fune", ""); }
        function start(): void { Fune.start(); }
        function pause(): void { Fune.pause(); }
        function resume(): void { Fune.resume(); }
        function stop(): void { Fune.stop(); }
        function desktop(): void { Fune.desktop(); }
        function status(): string { return Fune.status(); }
        // from bin/ocarina-fune: the island says «Windows despertando…» while it boots for an app
        function waking(): void { Fune.wake(); }
        function ready(): void { Fune.wokeUp(); }
        function opening(): void { Fune.opened(); }
        function refresh(): void { Fune.refresh(); Fune.refreshApps(); }
    }
    IpcHandler {
        target: "snake"
        function toggle(): void { Snake.toggle(); }
        function open(): void { Panels.show("snake", ""); }
        // a question from Torii (;), fish (`snake …`) or a test: opens the assistant and asks
        function ask(text: string): void { Panels.show("snake", ""); Snake.ask(text); }
        function status(): string { return Snake.status(); }
        // 声 voice: opens the assistant and listens (again = stop and transcribe)
        function listen(): void { Panels.show("snake", ""); Snake.listen(); }
        // from bin/ocarina-snake serve
        function loaded(name: string): void { Snake.onLoaded(name); }
        function unloaded(): void { Snake.onUnloaded(); }
    }
    IpcHandler {
        target: "apps"
        function toggle(): void { Apps.toggle(); }
    }
    IpcHandler {
        target: "mamori"
        function status(): string { return Mamori.status(); }
        // asked by bin/ocarina-mamori before installing: idle ≥ 10 min, locked, «Despierto»
        function conditions(): string { return Mamori.conditions(); }
        function refresh(): void { Mamori.reload(); }
        function run(): void { Mamori.runNow(); }
        function open(): void { Settei.show("mamori"); }
    }
    IpcHandler {
        target: "theme"
        function set(id: string): void { ThemeCtl.setTheme(id); }
        function get(): string { return Theme.id; }
        // "#rrggbb", "wallpaper" or "" (the theme's own)
        function accent(hex: string): void { ThemeCtl.setAccent(hex === "" ? null : hex); }
    }
    IpcHandler {
        target: "record"
        function toggle(): void { Recorder.toggle(); }
        function region(): void { Recorder.recording ? Recorder.stop() : Recorder.start(true); }
    }
    IpcHandler {
        target: "osd"
        function show(kind: string, value: string): void { Osd.show(kind, parseFloat(value) || 0, "", ""); }
        function info(text: string, icon: string): void { Osd.show("info", 0, text, icon); }
    }
    IpcHandler {
        target: "displays"
        function arrange(): void { Settei.show("pantalla"); }
        function identify(): void { Displays.identify(); }
        function mirror(on: bool): void { if (on) Displays.startMirror(); else Displays.stopMirror(); }
        function profile(name: string): string {
            const fp = Object.keys(Displays.profiles).find(k => Displays.profiles[k].name === name);
            if (!fp)
                return "no existe el perfil «" + name + "»";
            if (fp !== Displays.fingerprint)
                return "el perfil «" + name + "» es para otros monitores";
            Displays.applyProfile(fp);
            return "ok";
        }
        function list(): string { return Displays.status(); }
        function keep(): void { Displays.keep(); }
        function revert(): void { Displays.revert(); }
        // tests/captures (mockup 12): a simulated 27″ monitor; nothing is written while it is on
        function fake(on: bool): void { Displays.setFake(on); }
        // tests: a 15 s trial that rewrites outputs.kdl with the live (identical) configuration
        function trialNoop(): void { Displays.change("Prueba sin cambios", Displays.liveCfg()); }
    }
    IpcHandler {
        target: "focus"
        function start(minutes: int): void { Focus.start(minutes); }
        function stop(): void { Focus.stop(); }
        function status(): string { return Focus.status(); }
    }
    IpcHandler {
        target: "nightlight"
        function set(mode: string): void { NightLight.setMode(mode); }
        function toggle(): void { NightLight.toggle(); }
    }
    IpcHandler {
        target: "idle"
        function inhibit(): void { Idle.toggleInhibit(); }
        function status(): string { return Idle.status(); }
    }
    IpcHandler {
        target: "session"
        function save(): string { Session.saveNow(); return "ok"; }
        function restore(): string { return Session.restore(); }
        function status(): string { return Session.status(); }
    }
    IpcHandler {
        target: "backup"
        // 控 Hikae = snapper snapshots of ~ (D-070); the CLI does the work, the Settei section comes in phase 16
        function now(): string { Quickshell.execDetached(["ocarina", "backup", "now"]); return "ok"; }
        function status(): string { return "ocarina backup status (la sección 控 de Ajustes llega en la fase 16)"; }
        function restore(path: string): string {
            Quickshell.execDetached(["ocarina", "backup", "restore", path]);
            return "restaurando en ~/Restaurado/";
        }
    }
    IpcHandler {
        target: "updates"
        function status(): string {
            return JSON.stringify({ pending: Updates.pending, critical: Updates.critical, kernelChanged: Updates.kernelChanged,
                                    rebootNeeded: Updates.rebootNeeded, checkedAt: Updates.checkedAt, allowed: Updates.allowed,
                                    error: Updates.error });
        }
        function refresh(): void { Updates.refresh(true); }
    }
    IpcHandler {
        target: "iro"
        function pick(): void { Iro.pick(); }
        function status(): string { return Iro.status(); }
        function preview(hex: string): void { Iro.show(hex); }   // ("show" is taken by the qs ipc CLI)
    }
    IpcHandler {
        target: "yomu"
        function region(translate: bool): void { Yomu.region(translate); }
        function status(): string { return Yomu.status(); }
        function file(path: string): void { Yomu.file(path); }          // tests: OCR an image, show the card
        function translate(): void { Yomu.translate(); }
    }
}
