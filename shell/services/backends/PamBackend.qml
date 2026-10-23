pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam

// PAM for Kagi, created at runtime by services/Lock (docs/06 capa 3.1: if Quickshell.Services.Pam changes after an
// update only this file fails — Lock then locks with swaylock — instead of every file that imports qs.services).
// Two conversations: password.conf (pam_unix) and fingerprint.conf (pam_fprintd), both in shell/pam (D-040).
// The secret is kept only until PAM asks for it and is never logged.
Scope {
    id: root

    required property string dir

    signal passwordDone(int outcome)      // 0 success · 1 wrong · 2 error
    signal fingerDone(int outcome)        // 0 success · 1 no match · 2 error/timeout/reader gone

    readonly property bool passwordActive: pw.active
    readonly property bool fingerActive: fp.active

    QtObject {
        id: priv
        property string secret: ""
    }

    function tryPassword(secret: string): bool {
        if (pw.active)
            pw.abort();
        priv.secret = secret;
        if (pw.start())
            return true;
        priv.secret = "";
        return false;
    }
    function abortPassword(): void {
        priv.secret = "";
        if (pw.active)
            pw.abort();
    }
    function startFinger(): bool {
        return fp.active || fp.start();
    }
    function abortFinger(): void {
        if (fp.active)
            fp.abort();
    }

    PamContext {
        id: pw
        configDirectory: root.dir
        config: "password.conf"
        onPamMessage: {
            if (!responseRequired)
                return;
            if (priv.secret !== "") {
                respond(priv.secret);
                priv.secret = "";
            } else {
                // a second prompt (expired password…) cannot be answered from the lock screen
                abort();
                root.passwordDone(2);
            }
        }
        onCompleted: result => {
            priv.secret = "";
            root.passwordDone(result === PamResult.Success ? 0 : result === PamResult.Error ? 2 : 1);
        }
    }

    PamContext {
        id: fp
        configDirectory: root.dir
        config: "fingerprint.conf"
        // pam_fprintd: no match after max-tries → Failed; timeout or reader trouble → Error/MaxTries
        onCompleted: result => root.fingerDone(result === PamResult.Success ? 0 : result === PamResult.Failed ? 1 : 2)
    }
}
