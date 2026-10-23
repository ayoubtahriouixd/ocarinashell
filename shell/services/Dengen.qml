pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 電源 Dengen — the power menu (mockup 05). Five actions; logout, reboot and power-off must be HELD 1.2 s.
// Before leaving (logout/reboot/power-off) the session is saved for 復元 Fukugen. "Update and reboot" takes over the
// 再 card when 守 Mamori leaves a reboot pending (phase 16 writes the flag; the reboot itself goes through it).
Singleton {
    id: root

    property bool open: false
    property string screen: ""
    property int selected: 0
    readonly property int holdMs: 1200
    property real previewHold: -1          // tests/captures only (IPC `power preview`): draws the fill, runs nothing

    readonly property var actions: [
        { id: "lock", kanji: "鍵", key: "L", label: "Bloquear", verb: "bloquear", destructive: false },
        { id: "suspend", kanji: "眠", key: "S", label: "Suspender", verb: "suspender", destructive: false },
        { id: "logout", kanji: "退", key: "E", label: "Cerrar sesión", verb: "cerrar sesión", destructive: true },
        { id: "reboot", kanji: "再", key: "R", label: rebootPending ? "Actualizar y reiniciar" : "Reiniciar",
          verb: rebootPending ? "actualizar y reiniciar" : "reiniciar", destructive: true },
        { id: "poweroff", kanji: "終", key: "P", label: "Apagar", verb: "apagar", destructive: true }
    ]

    // Mamori (phase 16) leaves this flag when an update needs a reboot
    readonly property string rebootFlag: Paths.state + "/mamori/reboot-pending"
    property bool rebootPending: false
    FileView {
        id: pendingFile
        path: root.rebootFlag
        printErrors: false
        watchChanges: true
        onLoaded: root.rebootPending = true
        onLoadFailed: root.rebootPending = false
        onFileChanged: reload()
    }

    function toggle(): void {
        // the power button while locked: sleep (Dengen never opens over Kagi)
        if (Lock.active) {
            if (!Lock.test)
                Quickshell.execDetached(["systemctl", "suspend"]);
            return;
        }
        if (open)
            close();
        else
            show();
    }
    function show(): void {
        if (Lock.active)
            return;
        // the focused output, or the first screen if niri does not say (a window must exist for `open`)
        const f = Niri.focusedOutput;
        screen = Quickshell.screens.some(s => s.name === f) ? f : (Quickshell.screens[0]?.name ?? "");
        if (screen === "")
            return;
        selected = rebootPending ? 3 : 0;
        pendingFile.reload();
        open = true;
    }
    function close(): void {
        open = false;
        previewHold = -1;
    }

    function run(id: string): void {
        close();
        switch (id) {
        case "lock":
            Lock.lock();
            break;
        case "suspend":
            // ocarina-sleep.service locks before the system sleeps (before-sleep → ocarina lock --wait)
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "logout":
            // only here, and only because the user held the key: niri ends the session
            farewell(["niri", "msg", "action", "quit", "--skip-confirmation"], "logout");
            break;
        case "reboot":
            farewell(["systemctl", "reboot"], "reboot");
            break;
        case "poweroff":
            farewell(["systemctl", "poweroff"], "shutdown");
            break;
        }
    }

    // ── さようなら the farewell (modules/dengen/Farewell.qml) ──────────────────────────────────────
    // A full-screen overlay fades to Plymouth's background and puts the icon and message exactly where Plymouth will,
    // so the shutdown splash takes over without a visible jump. The command runs when three things are done: the
    // farewell has been seen (`farewellShown`, instant without Motion), the session is saved for 復元 Fukugen (2 s at
    // most) and, if 船 Fune has Windows on, Windows has shut down cleanly (30 s at most).
    property string farewellKind: ""       // "" | shutdown | reboot | logout
    readonly property bool leaving: farewellKind !== ""
    property bool farewellShown: false
    property bool sessionSaved: false
    property bool funeDone: false
    property var leaveCommand: []
    function farewell(command: var, kind: string): void {
        if (leaving)
            return;
        leaveCommand = command;
        farewellShown = false;
        sessionSaved = false;
        funeDone = !Fune.on;
        farewellKind = kind;
        shownGuard.restart();
        saveGuard.restart();
        Session.saveNow(true);
        if (!funeDone) {
            Fune.stop();
            funeGuard.restart();
        }
        Sounds.play("farewell");
    }
    // the overlay calls this once the icon and message are on screen
    function shown(): void {
        farewellShown = true;
        go();
    }
    function go(): void {
        if (farewellTest) {
            if (farewellShown)
                testEnd.restart();
            return;
        }
        if (!leaving || !farewellShown || !sessionSaved || !funeDone || leaveTimer.running)
            return;
        leaveTimer.start();
    }
    // test mode (IPC `power farewell <kind>`, captures): the same overlay, nothing saved, stopped or run; Esc or 4 s
    property bool farewellTest: false
    function testFarewell(kind: string): void {
        if (leaving || ["shutdown", "reboot", "logout"].indexOf(kind) < 0)
            return;
        farewellTest = true;
        farewellShown = false;
        funeDone = true;
        farewellKind = kind;
    }
    function endTest(): void {
        if (!farewellTest)
            return;
        testEnd.stop();
        farewellKind = "";
        farewellTest = false;
    }
    Timer {
        id: testEnd
        interval: 4000
        onTriggered: root.endTest()
    }
    Timer {
        id: leaveTimer
        // a breath with the final image on screen (and for the note), then the command
        interval: Motion.enabled ? 700 : 150
        onTriggered: Quickshell.execDetached(root.leaveCommand)
    }
    Connections {
        target: Session
        function onDidSave() {
            if (root.leaving) {
                root.sessionSaved = true;
                root.go();
            }
        }
    }
    // the overlay may fail to load (a broken file after an update): the command still runs
    Timer {
        id: shownGuard
        interval: 2500
        onTriggered: { root.farewellShown = true; root.go(); }
    }
    Timer {
        id: saveGuard
        interval: 2000
        onTriggered: { root.sessionSaved = true; root.go(); }
    }
    Connections {
        target: Fune
        function onOnChanged() {
            if (root.leaving && !Fune.on) {
                root.funeDone = true;
                root.go();
            }
        }
    }
    Timer {
        id: funeGuard
        interval: 30000
        onTriggered: { root.funeDone = true; root.go(); }
    }

    // ── ようこそ the arrival: once per login (not on shell restarts or hot reloads) the startup phrase plays and the bar
    // comes down from above (Obi reads `arriving`). $XDG_RUNTIME_DIR lives exactly as long as the login.
    property bool arriving: false
    readonly property string arrivedFlag: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ocarinashell/arrived"
    FileView {
        path: root.arrivedFlag
        printErrors: false
        blockLoading: true                  // known before the bar's first frame: no flash, no slide on reloads
        onLoadFailed: {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && : > \"$1\"", "sh", root.arrivedFlag]);
            if (Motion.enabled)
                root.arriving = true;
            arrival.start();
            Sounds.play("startup");
        }
    }
    Timer {
        id: arrival
        interval: 450                       // the first frames are up: let the bar slide in
        onTriggered: root.arriving = false
    }

    // greeting by the hour: お疲れさま during the day, おやすみなさい at night
    readonly property string greeting: {
        const h = Time.now.getHours();
        const g = Glossary.g.greetings ?? {};
        return (h >= 21 || h < 5) ? (g.shutdown?.jp ?? "おやすみなさい") : (g.goodWork?.jp ?? "お疲れさま");
    }
}
