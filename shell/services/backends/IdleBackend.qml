import QtQuick
import Quickshell
import Quickshell.Wayland

// Sensitive type (Quickshell.Wayland › IdleMonitor) isolated in its own file (docs/06 capa 3.1). The policy stays in
// services/Idle (`owner`); this file only arms the monitors and reports their edges back.
Scope {
    id: backend

    required property QtObject owner
    readonly property bool longIdle: longMon.isIdle
    readonly property bool idle10: mamoriMon.isIdle

    // IdleMonitor arms ext-idle-notify with the timeout it has when enabled; changing `timeout` later is ignored
    // (verified on 0.3.2), so the monitors are rebuilt whenever the profile changes (owner.key).
    Variants {
        model: [backend.owner.key]
        delegate: Scope {
            required property string modelData
            IdleMonitor {
                enabled: backend.owner.seconds(backend.owner.profile.dim) > 0
                timeout: backend.owner.seconds(backend.owner.profile.dim)
                respectInhibitors: true
                onIsIdleChanged: backend.owner.dimEdge(isIdle)
                Component.onDestruction: if (backend.owner.dimIdle) backend.owner.dimEdge(false)
            }
            IdleMonitor {
                enabled: backend.owner.seconds(backend.owner.profile.lock) > 0 && !backend.owner.lockActive
                timeout: backend.owner.seconds(backend.owner.profile.lock)
                respectInhibitors: true
                onIsIdleChanged: backend.owner.lockEdge(isIdle)
            }
            IdleMonitor {
                enabled: backend.owner.seconds(backend.owner.profile.screenOff) > 0 && !backend.owner.lockActive
                timeout: backend.owner.seconds(backend.owner.profile.screenOff)
                respectInhibitors: true
                onIsIdleChanged: backend.owner.offEdge(isIdle)
            }
            IdleMonitor {
                enabled: backend.owner.seconds(backend.owner.profile.suspend) > 0
                timeout: backend.owner.seconds(backend.owner.profile.suspend)
                respectInhibitors: true
                onIsIdleChanged: backend.owner.sleepEdge(isIdle)
            }
        }
    }
    IdleMonitor {
        id: longMon
        timeout: 15 * 60
        respectInhibitors: false
    }
    // 守 Mamori installs only after 10 min away (a playing video inhibits: you may be watching it)
    IdleMonitor {
        id: mamoriMon
        timeout: 10 * 60
        respectInhibitors: true
    }
}
