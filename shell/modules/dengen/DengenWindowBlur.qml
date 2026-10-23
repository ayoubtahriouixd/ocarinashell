import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.dengen

// Dengen with compositor blur behind the whole scrim (niri ext-background-effect; mockup: blur 18). If this file fails
// after an update, ModuleLoader falls back to the plain DengenWindow (darker scrim, no blur).
DengenWindow {
    id: win
    blurred: Theme.blur
    BackgroundEffect.blurRegion: blurred ? blur : null
    Region {
        id: blur
        item: win.contentItem
    }
}
