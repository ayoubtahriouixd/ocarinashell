import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.torii

// Torii with compositor blur behind the panel (niri ext-background-effect). If this file fails after an update,
// ModuleLoader falls back to the plain ToriiWindow (opaque glass).
ToriiWindow {
    id: win
    blurred: true
    BackgroundEffect.blurRegion: Theme.blur ? blur : null
    Region {
        id: blur
        item: win.panelItem
        radius: Theme.radius.panel
    }
}
