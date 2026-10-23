import QtQuick
import Quickshell
import Quickshell.Services.Greetd

// Sensitive module (Quickshell.Services.Greetd) isolated in its own file, created at run time by shell.qml: if the
// type changes after an update this file fails alone and greeter-launch falls back to agreety (docs/06 capa 3.1).
// Same shape as the test backend in shell.qml: start(user), answer(text), cancel(), launch(cmd) and the signals.
QtObject {
    id: backend

    readonly property bool real: true
    readonly property bool available: Greetd.available
    signal prompt(string message, bool secret)      // PAM wants an answer (password, or a visible question)
    signal info(string message, bool error)          // PAM says something (fingerprint hint, account notice…)
    signal failed(string message)                    // wrong password: start again
    signal greetdError(string message)               // greetd itself failed (socket, protocol): not the password
    signal ready                                     // authenticated: launch() may be called
    signal launched

    function start(user: string): void {
        Greetd.createSession(user);
    }
    function answer(text: string): void {
        Greetd.respond(text);
    }
    function cancel(): void {
        Greetd.cancelSession();
    }
    function launch(command: var): void {
        Greetd.launch(command, [], true);
    }

    property Connections conn: Connections {
        target: Greetd
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool) {
            if (responseRequired)
                backend.prompt(message, !echoResponse);
            else
                backend.info(message, error);
        }
        function onAuthFailure(message: string) {
            backend.failed(message);
        }
        function onError(error: string) {
            backend.greetdError(error);
        }
        function onReadyToLaunch() {
            backend.ready();
        }
        function onLaunched() {
            backend.launched();
        }
    }
}
