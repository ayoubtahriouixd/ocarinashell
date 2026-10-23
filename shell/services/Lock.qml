pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 鍵 Kagi state and authentication (docs/historia/fases/fase-06). The module (modules/kagi) only draws; everything that decides
// whether the session opens lives here, so a broken UI can never unlock by itself.
// - PAM in services/backends/PamBackend.qml, created at runtime (if it cannot load, every lock is swaylock): Kagi's own
//   files in shell/pam (D-040), password always + fingerprint in parallel when fingers are enrolled.
// - Real lock = WlSessionLock (ext-session-lock). Test mode (`ocarina lock test`) = the same UI on an Overlay layer that
//   closes with Esc and unlocks itself after 60 s. Test and real never share state: every lock starts a new `epoch`
//   and a success only releases the lock of its own epoch.
// - Safety nets: a flag in $XDG_RUNTIME_DIR survives a crash (the restarted shell locks again; a second start while
//   locked goes straight to swaylock, so a Kagi that crashes cannot loop); Kagi not confirmed by the compositor in
//   2.5 s → swaylock. swaylock releases our state only when it exits 0 (= the user authenticated); if it dies, it is
//   started again. Hot reload is off while locked (shell.qml).
Singleton {
    id: root

    // ------------------------------------------------------------------ public, read-only state
    readonly property bool active: p.active               // Kagi requested (real or test)
    readonly property bool test: p.test
    readonly property bool secure: p.secure               // compositor confirmed every output is covered
    readonly property bool unlocking: p.unlocking         // success: burst + dissolve running
    readonly property bool ghost: p.ghost                 // the dissolving overlay copy is wanted (D-042)
    readonly property bool fallback: sway.running         // swaylock holds (or is taking) the lock
    readonly property bool locked: (active && !test && secure && !unlocking) || p.swayReady
    // Kagi's WlSessionLock should hold the session (not when swaylock is the only locker)
    readonly property bool kagiWanted: active && !test && !p.swayOnly
    readonly property bool pamReady: p.backend !== null
    readonly property double lockedAt: p.lockedAt
    readonly property bool checking: p.checking
    readonly property int failures: p.failures
    readonly property double waitUntil: p.waitUntil
    readonly property string message: p.message
    readonly property bool fingerprint: p.fingers && pamReady && Settings.data.lock.fingerprint
    readonly property string fingerHint: p.fingerHint
    readonly property int driftStep: p.driftStep          // 保護 Hogo drift, shared by every view (ghost included)

    // Kagi's own idle: 30 s without input while really locked → monitors off (any key turns them on again)
    readonly property bool screenOff: p.idleBackend?.isIdle ?? false

    readonly property string userName: {
        const u = Quickshell.env("USER") ?? "";
        return u.charAt(0).toUpperCase() + u.slice(1);
    }

    signal failed()
    signal succeeded()

    readonly property string flagDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ocarinashell"
    readonly property string flagPath: flagDir + "/locked"

    QtObject {
        id: p
        property bool active: false
        property bool test: false
        property bool secure: false
        property bool unlocking: false
        property bool ghost: false
        property bool swayReady: false
        property bool swayOnly: false
        property int swayRetries: 0
        property int epoch: 0
        property int attemptEpoch: -1
        property double lockedAt: 0
        property bool checking: false
        property int failures: 0
        property double waitUntil: 0
        property string message: ""
        property bool fingers: false
        property string fingerHint: ""
        property int fingerFails: 0
        property int fingerErrors: 0
        property int driftStep: 0
        property QtObject backend: null
        property QtObject idleBackend: null
    }

    // ------------------------------------------------------------------ entry points
    function lock(): void {
        if (p.active && !p.test && !p.unlocking)
            return;                                   // already locked
        // from test mode, or during a real unlock's dissolve: a brand-new real lock (the compositor is still locked
        // in the second case, so cancelling the release is safe)
        Dengen.close();
        p.test = false;
        p.active = true;
        begin();
        Sounds.play("lock");
        Sounds.locked = true;
        writeFlag(0);
        if (p.backend === null || p.swayOnly) {
            if (p.backend === null)
                console.warn("Kagi: PAM no disponible → swaylock");
            startSway(true);
        } else {
            watchdog.restart();
        }
    }

    function startTest(): string {
        if (p.active)
            return p.test ? "ya en modo prueba" : "la sesión ya está bloqueada";
        if (p.backend === null)
            return "PAM no disponible: el bloqueo usaría swaylock";
        p.test = true;
        p.active = true;
        begin();
        testTimer.restart();
        return "modo prueba: Esc para salir, se desbloquea solo a los 60 s";
    }

    // Esc (or IPC) in test mode: never touches a real lock
    function leaveTest(): void {
        if (p.active && p.test)
            release(p.epoch);
    }
    // the test window finished its dissolve after a success
    function testDissolved(): void {
        if (p.active && p.test && p.unlocking)
            release(p.epoch);
    }
    // the ghost copy has faded away
    function ghostDone(): void {
        p.ghost = false;
    }
    // reported by Kagi's WlSessionLock
    function reportSecure(s: bool): void {
        p.secure = s && p.active && !p.test;
        if (p.secure) {
            watchdog.stop();
            stable.restart();
        }
    }

    function submit(secret: string): bool {
        if (!p.active || p.unlocking || p.checking || secret === "" || p.backend === null || Date.now() < clampWait())
            return false;
        p.checking = true;
        p.message = "";
        p.attemptEpoch = p.epoch;
        if (!p.backend.tryPassword(secret)) {
            p.checking = false;
            p.message = "No se pudo iniciar la autenticación";
            return false;
        }
        pamTimeout.restart();
        return true;
    }

    function waitSeconds(): int {
        return Math.max(0, Math.ceil((clampWait() - Date.now()) / 1000));
    }
    // a clock jump backwards (NTP after resume) must never stretch the wait beyond its 60 s maximum
    function clampWait(): double {
        if (p.waitUntil > Date.now() + 60000)
            p.waitUntil = Date.now() + 60000;
        return p.waitUntil;
    }

    // ------------------------------------------------------------------ internals
    function begin(): void {
        p.epoch++;
        p.lockedAt = Date.now();
        p.unlocking = false;
        p.ghost = false;
        p.checking = false;
        p.attemptEpoch = -1;
        p.failures = 0;
        p.waitUntil = 0;
        p.message = "";
        p.fingerHint = "";
        p.fingerFails = 0;
        p.fingerErrors = 0;
        handoff.stop();
        testFloor.stop();
        pamTimeout.stop();
        testTimer.stop();
        if (p.backend !== null) {
            p.backend.abortPassword();
            p.backend.abortFinger();
        }
        fingerCheck.running = true;
    }

    function succeed(ep: int): void {
        if (ep !== p.epoch || p.unlocking || !p.active)
            return;
        p.unlocking = true;
        p.checking = false;
        p.message = "";
        pamTimeout.stop();
        if (p.backend !== null) {
            p.backend.abortPassword();
            p.backend.abortFinger();
        }
        Sounds.locked = false;
        Sounds.play("unlock");
        succeeded();
        if (p.test) {
            testFloor.restart();                       // the test window calls testDissolved(); this is the floor
        } else if (Motion.enabled) {
            p.ghost = true;                            // Kagi maps the ghost while the burst plays
            handoff.ep = p.epoch;
            handoff.restart();
        } else {
            release(p.epoch);
        }
    }

    function release(ep: int): void {
        if (!p.active || ep !== p.epoch)
            return;
        if (!p.test && !p.unlocking)
            return;                                    // a real lock opens only after a success of this epoch
        handoff.stop();
        testFloor.stop();
        watchdog.stop();
        testTimer.stop();
        pamTimeout.stop();
        if (p.backend !== null) {
            p.backend.abortPassword();
            p.backend.abortFinger();
        }
        if (!p.test)
            Quickshell.execDetached(["rm", "-f", flagPath]);
        p.active = false;
        p.test = false;
        p.secure = false;
        p.unlocking = false;
        p.checking = false;
        p.swayOnly = false;
        Sounds.locked = false;
    }

    function writeFlag(n: int): void {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/locked"', "sh", flagDir, String(n)]);
    }

    // ------------------------------------------------------------------ PAM backend
    Component.onCompleted: {
        const c = Qt.createComponent("backends/PamBackend.qml");
        if (c.status === Component.Ready) {
            p.backend = c.createObject(root, { dir: Paths.shell + "/pam" });
            p.backend.passwordDone.connect(onPassword);
            p.backend.fingerDone.connect(onFinger);
        } else {
            Health.fail("Kagi · PAM (Quickshell.Services.Pam)", c.errorString());
        }
        const ci = Qt.createComponent("backends/LockIdleBackend.qml");
        if (ci.status === Component.Ready)
            p.idleBackend = ci.createObject(root, { owner: root });
        else
            Health.fail("Kagi · pantalla apagada (IdleMonitor)", ci.errorString());
        wallcache.refresh();
        startupFlag.running = true;
    }

    function onPassword(outcome: int): void {
        pamTimeout.stop();
        const ep = p.attemptEpoch;
        p.attemptEpoch = -1;
        if (ep !== p.epoch)
            return;                                    // an answer for a lock that no longer exists
        p.checking = false;
        if (outcome === 0) {
            succeed(ep);
            return;
        }
        p.failures++;
        p.message = outcome === 2 ? "Error de autenticación" : "Contraseña incorrecta";
        // 3 → 5 s, 4 → 15 s, 5 → 30 s, then 60 s (never a lockout: D-040)
        if (p.failures >= 3)
            p.waitUntil = Date.now() + [5, 15, 30, 60][Math.min(3, p.failures - 3)] * 1000;
        failed();
    }

    // a PAM conversation that never answers must not freeze the field
    Timer {
        id: pamTimeout
        interval: 15000
        onTriggered: {
            if (!p.checking)
                return;
            p.backend?.abortPassword();
            p.attemptEpoch = -1;
            p.checking = false;
            p.message = "La autenticación no respondió: vuelve a intentarlo";
        }
    }

    // ------------------------------------------------------------------ fingerprint (parallel, optional)
    // Only "no match" counts towards the limit; timeouts and reader errors retry quietly (a few times). Turning the
    // screen on again gives the reader a fresh start.
    readonly property bool fingerWanted: p.active && !p.unlocking && p.fingers && p.backend !== null && !screenOff
        && Settings.data.lock.fingerprint
                                         && p.fingerFails < 5 && p.fingerErrors < 4
    onFingerWantedChanged: {
        if (fingerWanted)
            fingerStart.restart();
        else
            p.backend?.abortFinger();
    }
    onScreenOffChanged: {
        if (!screenOff) {
            p.fingerErrors = 0;
            p.fingerFails = 0;
        }
    }
    function onFinger(outcome: int): void {
        if (outcome === 0) {
            succeed(p.epoch);
            return;
        }
        if (outcome === 1) {
            p.fingerFails++;
            p.fingerHint = "Huella no reconocida";
        } else {
            p.fingerErrors++;
        }
        if (fingerWanted)
            fingerStart.restart();
    }
    Process {
        id: fingerCheck
        command: ["fprintd-list", Quickshell.env("USER") ?? ""]
        stdout: StdioCollector {
            onStreamFinished: p.fingers = /#\d+:/.test(text)
        }
    }
    Timer {
        id: fingerStart
        interval: 800
        onTriggered: if (root.fingerWanted) p.backend.startFinger()
    }

    // ------------------------------------------------------------------ timers
    Timer {
        id: handoff
        property int ep: -1
        // the burst plays on the lock surface while the ghost maps underneath (niri maps a layer in ~24 ms, D-033)
        interval: 320
        onTriggered: root.release(ep)
    }
    Timer {
        id: testFloor
        interval: 1500
        onTriggered: if (p.test) root.release(p.epoch)
    }
    Timer {
        id: testTimer
        interval: 60000
        onTriggered: root.leaveTest()
    }
    // Kagi confirmed for 5 s: the crash counter in the flag goes back to 0
    Timer {
        id: stable
        interval: 5000
        onTriggered: if (root.locked) root.writeFlag(0)
    }
    Timer {
        id: watchdog
        interval: 2500
        onTriggered: {
            if (p.active && !p.test && !p.secure) {
                console.warn("Kagi: el compositor no confirmó el bloqueo en 2,5 s → swaylock");
                root.startSway(false);
            }
        }
    }

    // ------------------------------------------------------------------ swaylock fallback
    // `--ready-fd 3` writes a line once swaylock is on screen; it exits 0 only after a successful unlock.
    function startSway(only: bool): void {
        p.swayOnly = p.swayOnly || only;
        p.swayRetries = 0;
        if (!sway.running)
            sway.running = true;
    }
    Process {
        id: sway
        command: ["sh", "-c", "exec swaylock -c 0b0a0c --ready-fd 3 3>&1"]
        stdout: SplitParser {
            onRead: p.swayReady = true
        }
        onExited: code => {
            p.swayReady = false;
            if (code === 0) {
                // the user authenticated in swaylock: our request goes too
                p.swayOnly = false;
                if (p.active && !p.test && !p.secure) {
                    p.unlocking = true;
                    root.release(p.epoch);
                }
                return;
            }
            // refused (Kagi holds the lock) or died (pkill, crash): never treated as an unlock
            if (p.active && !p.test && !p.secure && p.swayRetries < 5) {
                p.swayRetries++;
                swayRetry.restart();
            }
        }
    }
    Timer {
        id: swayRetry
        interval: 1000
        onTriggered: if (p.active && !p.secure && !sway.running) sway.running = true
    }

    // screens off after 30 s idle while locked: the IdleMonitor lives in backends/LockIdleBackend.qml (capa 3.1)
    readonly property bool idleArmed: p.active && !p.test
    function lockedIdle(): void {
        if (p.active && !p.unlocking)
            Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
    }
    // 保護 Hogo drift: one step a minute with the clock, never while typing/checking (views report typing)
    property bool typing: false
    Connections {
        target: Time
        function onMinuteTick() {
            if (p.active && Settings.data.oled.lockDrift && !root.typing && !p.checking)
                p.driftStep = (p.driftStep + 1) % 8;
        }
    }

    // Backdrop: the wallpaper pre-blurred by ocarina-wallcache, resolved ahead of time so the lock appears complete
    readonly property string wallpaper: Modes.shinobi ? "" : (Settings.data.wallpaper.path || Theme.wallpaper)
    property string backdrop: ""
    readonly property string wallpaperPath: wallpaper === "" ? "" : wallpaper.startsWith("/") ? wallpaper : Paths.wallpapers + "/" + wallpaper
    onWallpaperChanged: wallcache.refresh()
    Process {
        id: wallcache
        function refresh(): void {
            if (root.wallpaper === "") {
                root.backdrop = "";
                return;
            }
            command = [Paths.bin + "/ocarina-wallcache", root.wallpaper];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f !== "")
                    root.backdrop = f;
            }
        }
    }

    // 諺 proverb of the day for the 縦書き column: index = day of the year % count (assets/data/kotowaza.json)
    property var proverbs: []
    readonly property var proverb: {
        const n = proverbs.length;
        if (n === 0)
            return { jp: "", romaji: "", es: "" };
        const d = Time.now, start = new Date(d.getFullYear(), 0, 1);
        return proverbs[Math.floor((d - start) / 86400000) % n];
    }
    FileView {
        path: Paths.asset("data/kotowaza.json")
        printErrors: true
        onLoaded: {
            try {
                root.proverbs = JSON.parse(text()).kotowaza ?? [];
            } catch (e) {
                console.warn("Kagi: kotowaza.json ilegible:", e);
            }
        }
    }

    // A start of the shell with the flag present = it died while locked: lock again at once. The flag counts those
    // starts; the second one in a row skips Kagi (it may be what crashes) and goes to swaylock directly.
    Process {
        id: startupFlag
        command: ["sh", "-c", 'cat "$1" 2>/dev/null && echo " :flag"', "sh", root.flagPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.includes(":flag"))
                    return;
                const n = (parseInt(text) || 0) + 1;
                console.warn("Kagi: la sesión estaba bloqueada al arrancar (" + n + ") → bloqueo de nuevo");
                if (n >= 2)
                    p.swayOnly = true;             // before lock(): Kagi never asks for the session this time
                root.lock();
                root.writeFlag(n);
            }
        }
    }
}
