//@ pragma ShellId ocarina-greeter
//@ pragma Env QS_NO_RELOAD_POPUP=1
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// OcarinaShell greeter (fase 13, D-014/D-044): runs as the `greeter` user inside a minimal niri under greetd
// (system/greeter/greeter-launch). It starts on Plymouth's last boot frame — same background, icon and message in the
// same place — and then settles into the login form. Installed as a COPY in /usr/local/share/ocarinashell/greeter by
// scripts/root/greeter.sh (the greeter user cannot read ~ayoub); config/ and components/ are the shell's own.
//
// Test mode (no greetd, e.g. inside the session: `qs -p ~/ocarinashell/greeter`): nothing is authenticated or
// launched; «mal» is a wrong password, anything else succeeds; Esc quits.
ShellRoot {
    id: root

    // /etc/ocarinashell/greeter.json (written by scripts/root/greeter.sh): who logs in and what starts
    property var conf: ({ user: "ayoub", name: "Ayoub", variant: "dark", session: ["niri-session"] })
    FileView {
        path: Quickshell.env("OCARINA_GREETER_CONF") || "/etc/ocarinashell/greeter.json"
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                const j = JSON.parse(text());
                const c = Object.assign({}, root.conf);
                // only well-formed values: a bad one keeps the default instead of breaking Greetd.launch later
                if (typeof j.user === "string" && /^[a-z_][a-z0-9_-]*$/.test(j.user))
                    c.user = j.user;
                if (typeof j.name === "string")
                    c.name = j.name;
                if (j.variant === "dark" || j.variant === "light")
                    c.variant = j.variant;
                if (Array.isArray(j.session) && j.session.length > 0 && j.session.every(x => typeof x === "string"))
                    c.session = j.session;
                root.conf = c;
            } catch (e) {
                console.warn("greeter.json ilegible, uso los valores por defecto:", e);
            }
        }
    }
    readonly property string runDir: Quickshell.env("OCARINA_GREETER_RUN") || ""
    readonly property string assets: Quickshell.env("OCARINA_GREETER_ASSETS")
        || (Quickshell.shellDir.replace(/\/$/, "") + "/../assets/boot/plymouth/ocarinashell")

    property QtObject backend: null
    readonly property bool test: backend === null || !backend.real
    Component.onCompleted: {
        if (Quickshell.env("OCARINA_GREETER_TEST") !== "1") {
            const c = Qt.createComponent("GreetdBackend.qml");
            if (c.status === Component.Ready) {
                const b = c.createObject(root);
                if (b && b.available)
                    backend = b;
                else if (b)
                    b.destroy();
            } else {
                console.warn("Greetd no disponible:", c.errorString());
            }
        }
        // under greetd without a working backend: leave at once (exit 1 → greeter-launch counts a failure and, at the
        // second, starts agreety) instead of showing a test-mode form on the real login screen
        if (!backend && Quickshell.env("GREETD_SOCK") && Quickshell.env("OCARINA_GREETER_TEST") !== "1") {
            console.warn("greeter: bajo greetd sin backend de Greetd; salgo para que entre agreety");
            Qt.exit(1);
            return;
        }
        if (!backend)
            backend = testBackend;
        console.info("greeter:", test ? "modo prueba" : "greetd", "· usuario", conf.user, "· variante", conf.variant);
    }

    // the same interface as GreetdBackend, without greetd
    QtObject {
        id: testBackend
        readonly property bool real: false
        signal prompt(string message, bool secret)
        signal info(string message, bool error)
        signal failed(string message)
        signal greetdError(string message)
        signal ready
        signal launched
        property string pending: ""
        function start(user: string): void { Qt.callLater(() => prompt("Password: ", true)); }
        function answer(text: string): void {
            pending = text;
            testTimer.restart();
        }
        function cancel(): void {}
        function launch(command: var): void {
            console.info("greeter (prueba): lanzaría", JSON.stringify(command));
            launched();
            Qt.quit();
        }
    }
    // test mode never keeps the screen: 90 s and it is gone
    Timer {
        running: root.test
        interval: 90000
        onTriggered: Qt.quit()
    }
    Timer {
        id: testTimer
        interval: 600
        onTriggered: testBackend.pending === "mal" ? testBackend.failed("Authentication failure") : testBackend.ready()
    }

    // greeter-launch's markers: «ready» lets root quit Plymouth with --retain-splash (we are on screen),
    // «launched» tells it the session started (anything else after niri exits counts as a failure → agreety)
    function mark(name: string): void {
        if (runDir !== "")
            Quickshell.execDetached(["touch", runDir + "/" + name]);
    }

    Variants {
        model: Quickshell.screens
        delegate: Greeter {
            required property ShellScreen modelData
            screen: modelData
            main: modelData === Quickshell.screens[0]
            conf: root.conf
            backend: root.backend
            assets: root.assets
            test: root.test
            dryRun: Quickshell.env("OCARINA_GREETER_DRYRUN") === "1"
            onShown: if (main) root.mark("ready")
            onTestDone: root.mark("test-done")
            onSessionLaunched: root.mark("launched")
        }
    }
}
