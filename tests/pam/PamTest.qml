//@ pragma ShellId ocarina-pamtest
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Phase 6 · step 2: PamContext in a NORMAL window (no lock) with Kagi's own PAM files (shell/pam/).
// Run: qs -p ~/ocarinashell/tests/pam/PamTest.qml   (Ayoub types; Esc or «Cerrar» quits).
// Non-interactive checks: qs -p … ipc call pamtest tryPassword <text> · log · cancel · finger
ShellRoot {
    id: root

    property var lines: []
    function log(s: string): void {
        const l = Qt.formatTime(new Date(), "HH:mm:ss.zzz") + "  " + s;
        console.info("pamtest:", l);
        lines = [l].concat(lines).slice(0, 14);
    }
    property string pending: ""
    property double startedAt: 0

    PamContext {
        id: pw
        configDirectory: Quickshell.shellDir + "/../../shell/pam"
        config: "password.conf"
        onPamMessage: {
            root.log("pw msg: «" + message + "» error=" + messageIsError + " needs=" + responseRequired);
            if (responseRequired && root.pending !== "") {
                respond(root.pending);
                root.pending = "";
            }
        }
        onError: e => root.log("pw ERROR " + PamError.toString(e))
        onCompleted: r => root.log("pw RESULT " + PamResult.toString(r) + " (" + (Date.now() - root.startedAt) + " ms)")
    }

    PamContext {
        id: fp
        configDirectory: Quickshell.shellDir + "/../../shell/pam"
        config: "fingerprint.conf"
        onPamMessage: root.log("fp msg: «" + message + "» error=" + messageIsError + " needs=" + responseRequired)
        onError: e => root.log("fp ERROR " + PamError.toString(e))
        onCompleted: r => root.log("fp RESULT " + PamResult.toString(r))
    }

    function tryPassword(text: string): void {
        if (pw.active)
            pw.abort();
        pending = text;
        startedAt = Date.now();
        log("pw start → " + pw.start());
    }

    IpcHandler {
        target: "pamtest"
        function tryPassword(text: string): void { root.tryPassword(text); }
        function cancel(): void { pw.abort(); fp.abort(); root.log("abort pedido"); }
        function finger(): void { root.log("fp start → " + fp.start()); }
        function log(): string { return root.lines.join("\n"); }
    }

    FloatingWindow {
        title: "OcarinaShell · prueba PAM (fase 6)"
        implicitWidth: 620
        implicitHeight: 460
        color: "#141216"

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            Text {
                text: "鍵 Prueba de PamContext (no es el bloqueo)"
                color: "#f4efe6"; font.pixelSize: 18; font.family: "Geist"
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Escribe tu contraseña y pulsa Enter. Prueba también una errónea, «Cancelar» a mitad y, si tienes " +
                      "huellas registradas, «Huella». Nada de esto bloquea la sesión. Esc cierra."
                color: "#aaa39b"; font.pixelSize: 13; font.family: "Geist"
            }
            Rectangle {
                width: parent.width; height: 44; radius: 22
                color: "#1b181d"; border.color: "#463e48"
                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "#f4efe6"; font.pixelSize: 15
                    focus: true
                    onAccepted: { root.tryPassword(text); text = ""; }
                    Keys.onEscapePressed: Qt.quit()
                }
            }
            Row {
                spacing: 10
                Repeater {
                    model: [["Cancelar", () => { pw.abort(); fp.abort(); root.log("abort pedido"); }],
                            ["Huella", () => root.log("fp start → " + fp.start())],
                            ["Cerrar", () => Qt.quit()]]
                    delegate: Rectangle {
                        id: btn
                        required property var modelData
                        width: 110; height: 34; radius: 10
                        color: ma.containsMouse ? "#2e2830" : "#241f26"
                        Text { anchors.centerIn: parent; text: btn.modelData[0]; color: "#f4efe6"; font.pixelSize: 13 }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: btn.modelData[1]() }
                    }
                }
            }
            Text {
                text: "pw activo: " + pw.active + " · fp activo: " + fp.active
                color: "#6f6862"; font.pixelSize: 12
            }
            Text {
                width: parent.width
                text: root.lines.join("\n")
                color: "#f4efe6"; font.family: "JetBrainsMono Nerd Font"; font.pointSize: 9
            }
        }
    }
}
