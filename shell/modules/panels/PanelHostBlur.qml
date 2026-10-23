import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// PanelHost with compositor blur behind the open panel (niri ext-background-effect). If this file fails after an
// update, ModuleLoader falls back to the plain PanelHost (opaque glass).
PanelHost {
    id: win
    // 広場 is opaque ink: nothing to blur behind it
    // (by the panel that is LOADED, not by Panels.open: while it shrinks back into the island Panels.open is
    // already "", and a blur behind its whole rectangle would flash a box behind the ink)
    // 読 Yomu neither: it opens the instant slurp's full-screen layer goes away, and niri's blur behind it showed a
    // black box for a moment (Ayoub, fase 15); an opaque card reads better over any text anyway
    BackgroundEffect.blurRegion: Theme.blur && panelItem && win.which !== "hiroba" && win.which !== "yomu" ? blur : null
    Component.onCompleted: Panels.blurActive = true
    Component.onDestruction: Panels.blurActive = false
    Region {
        id: blur
        item: win.panelItem
        radius: Theme.radius.panel
    }
}
