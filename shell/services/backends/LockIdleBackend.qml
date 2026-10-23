import QtQuick
import Quickshell
import Quickshell.Wayland

// Sensitive type (Quickshell.Wayland › IdleMonitor) isolated in its own file (docs/06 capa 3.1): screens off after
// 30 s idle while Kagi holds a real lock. Without it the lock still works; the screens just stay on.
IdleMonitor {
    required property QtObject owner

    enabled: owner.idleArmed
    timeout: 30
    respectInhibitors: false
    onIsIdleChanged: if (isIdle) owner.lockedIdle()
}
