pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.services
import qs.modules.polkit

// 認 Polkit agent of the session (fase 06). Isolated in its own ModuleLoader: if Quickshell.Services.Polkit changes
// after an update only the dialog is lost (pkexec then fails with "no authentication agent"), never the shell.
// The dialog maps on the focused screen only while a request is active.
Scope {
    id: root

    PolkitAgent {
        id: agent
        onIsRegisteredChanged: console.info("Polkit: agente " + (isRegistered ? "registrado" : "NO registrado"))
        onAuthenticationRequestStarted: {
            console.info("Polkit: petición", flow?.actionId ?? "");
            root.screen = root.focusedScreen();      // fixed for the whole request (moving focus must not recreate it)
        }
    }

    property var screen: null
    function focusedScreen(): var {
        const name = Niri.focusedOutput;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    LazyLoader {
        active: agent.isActive && agent.flow !== null && root.screen !== null
        PolkitDialog {
            screen: root.screen
            flow: agent.flow
        }
    }
}
