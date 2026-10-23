import QtQuick
import Quickshell
import Quickshell.Wayland

// 醒 "Despierto" (idle-inhibit-unstable-v1). Own file, loaded only while enabled: if the protocol or the type
// changes after an update, only this feature is lost — never the bar that hosts it.
IdleInhibitor {
    enabled: window !== null
}
