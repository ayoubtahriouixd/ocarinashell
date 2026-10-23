import QtQuick
import qs.config
import qs.services

// Touch-only pull-down from the bar: opens `panel` following the finger (released past 40 % → opens, else springs
// back). Mouse and touchpad are unaffected (acceptedDevices = TouchScreen). Optional horizontal swipe signals.
DragHandler {
    id: root
    required property string panel
    property real distance: 260          // finger travel for 100 %
    signal swipeLeft
    signal swipeRight
    target: null
    enabled: Settings.data.extras.touchGestures       // Settei → Teclado y ratón
    acceptedDevices: PointerDevice.TouchScreen
    onActiveChanged: {
        if (active) {
            if (panel !== "")
                Panels.beginDrag(panel);
        } else {
            if (Math.abs(translation.x) > 80 && Math.abs(translation.x) > Math.abs(translation.y) * 1.5) {
                if (translation.x < 0) swipeLeft(); else swipeRight();
            }
            Panels.endDrag();
        }
    }
    onTranslationChanged: if (active && panel !== "") Panels.updateDrag(translation.y / distance)
}
