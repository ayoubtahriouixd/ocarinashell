pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// ocarina-dim — software brightness for screens without DDC/CI (D-009). Exists only while that screen's level is
// below 100 % (ModuleLoader.active). Overlay layer, no input (empty mask), no shadow (layer-rules), max 60 %.
PanelWindow {
    id: win

    WlrLayershell.namespace: "ocarina-dim"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}
    // 読 Yomu hides it while it captures: OCR reads the real pixels (D-009)
    color: Yomu.capturing ? "transparent"
         : Qt.rgba(0, 0, 0, Math.min(0.6, (100 - Brightness.softLevel(win.screen?.name ?? "")) / 100))
}
