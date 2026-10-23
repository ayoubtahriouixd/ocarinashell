import QtQuick

// Wheel / touchpad to discrete steps: accumulates angleDelta (or pixelDelta) and emits step(±1) every 120 units,
// so a touchpad flick (dozens of tiny events) is one or two steps, and horizontal scrolling is ignored.
WheelHandler {
    id: root
    signal step(int direction)        // +1 = up / away from the user
    property real acc: 0
    property real threshold: 120
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: ev => {
        const dy = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.pixelDelta.y * 4;
        if (dy === 0)
            return;
        acc += dy;
        while (Math.abs(acc) >= threshold) {
            const dir = acc > 0 ? 1 : -1;
            acc -= dir * threshold;
            step(dir);
        }
    }
}
