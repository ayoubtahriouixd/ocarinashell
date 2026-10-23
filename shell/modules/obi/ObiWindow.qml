import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.obi

// 帯 Obi window with compositor blur behind the glass (niri ext-background-effect, "xray": computed once).
// If this file fails to load (protocol or type gone after an update), ModuleLoader falls back to ObiWindowPlain.
ObiWindowPlain {
    id: win
    blurred: Theme.blur
    BackgroundEffect.blurRegion: !win.blurred ? null : win.isles ? capsShape : blurShape

    Region {
        id: blurShape
        x: 0
        y: 0
        width: win.hiddenFully ? 0 : win.width
        height: win.hiddenFully ? 0 : win.barHeight
        radius: win.attached ? 0 : Theme.radius.bar
    }
    // 島々 isles: only behind the two capsules (the rest of the bar is see-through, without blur)
    Region {
        id: capsShape
        Region { item: win.hiddenFully ? null : win.barItem.leftCap; radius: win.barItem.leftCap.radius }
        Region { item: win.hiddenFully ? null : win.barItem.rightCap; radius: win.barItem.rightCap.radius }
    }
}
