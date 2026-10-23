pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// 壁紙 Kabegami — wallpaper renderer, one per screen (background layer, inside niri's overview backdrop).
// Changing the image runs the 墨 ink-wipe shader; with Motion off it swaps at once. 忍 Shinobi: a black veil fades
// in (Motion.fade: the one animation allowed while the mode changes) and only then is the picture released.
// Two Image items swap roles: the one that just decoded the new picture becomes the visible one (one decode per
// change), and the old one is emptied to free its memory. A change during a transition is queued; a broken image
// falls back to the theme's wallpaper. The blurred copy for the lock screen is pre-rendered by ocarina-wallcache.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ocarina-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.colors.bg

    readonly property string wanted: {
        if (Modes.shinobi)
            return veil.opacity >= 1 ? "" : win.current;   // the picture stays under the veil until it is opaque
        const p = Settings.data.wallpaper.path;
        return p !== "" ? p : Theme.wallpaper;
    }
    readonly property size physical: Qt.size(Math.round(width * devicePixelRatio), Math.round(height * devicePixelRatio))
    readonly property bool firstScreen: Quickshell.screens.length > 0 && screen === Quickshell.screens[0]

    property string current: ""      // path shown now
    property string target: ""       // path being revealed
    property string queued: ""       // asked for during a transition
    property bool transitioning: false
    property bool aFront: true
    readonly property Image front: aFront ? imgA : imgB
    readonly property Image back: aFront ? imgB : imgA

    onWantedChanged: change(wanted)
    Component.onCompleted: change(wanted)

    function change(path: string): void {
        if (transitioning) {
            queued = path;
            return;
        }
        if (path === current)
            return;
        if (path !== "" && firstScreen)
            Quickshell.execDetached(["sh", "-c", 'command -v "$0" >/dev/null && exec "$0" "$1"', Paths.bin + "/ocarina-wallcache", path]);
        if (current === "" || path === "" || !Motion.enabled) {
            front.source = path === "" ? "" : Paths.url(path);
            back.source = "";
            current = path;
            return;
        }
        target = path;
        back.source = Paths.url(path);     // the wipe starts when it has decoded
    }

    function finish(): void {
        aFront = !aFront;                  // the revealed image is now the front one
        back.source = "";                  // free the old picture
        current = target;
        transitioning = false;
        ink.progress = 0;
        if (queued !== "" && queued !== current) {
            const q = queued;
            queued = "";
            change(q);
        }
        queued = "";
    }

    function onBackStatus(img: Image): void {
        if (img !== back || target === "" || transitioning)
            return;
        if (img.status === Image.Ready) {
            Health.ok("Kabegami");
            ink.seed = Math.random();
            ink.origin = Qt.point(0.25 + Math.random() * 0.5, 0.3 + Math.random() * 0.4);
            transitioning = true;
            wipe.restart();
        } else if (img.status === Image.Error) {
            Health.fail("Kabegami", "no se pudo cargar " + target);
            const fallback = Theme.wallpaper;
            target = "";
            img.source = "";
            if (fallback !== "" && fallback !== current)
                change(fallback);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Modes.shinobi ? Theme.oledBlack : Theme.colors.bg
    }
    Rectangle {
        id: veil
        anchors.fill: parent
        z: 3
        color: Theme.oledBlack
        opacity: Modes.shinobi ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.fade(Motion.emphasized); easing.type: Easing.InOutQuad } }
    }

    Image {
        id: imgA
        anchors.fill: parent
        z: win.aFront ? 1 : 0
        visible: win.aFront
        fillMode: Image.PreserveAspectCrop
        sourceSize: win.physical
        asynchronous: true
        cache: false
        onStatusChanged: win.onBackStatus(imgA)
    }
    Image {
        id: imgB
        anchors.fill: parent
        z: win.aFront ? 0 : 1
        visible: !win.aFront
        fillMode: Image.PreserveAspectCrop
        sourceSize: win.physical
        asynchronous: true
        cache: false
        onStatusChanged: win.onBackStatus(imgB)
    }

    ShaderEffect {
        id: ink
        anchors.fill: parent
        z: 2
        visible: win.transitioning
        property real progress: 0
        property real aspect: width / Math.max(1, height)
        property real seed: 0
        property point origin: Qt.point(0.5, 0.5)
        property color inkColor: Theme.alpha(Theme.colors.accent, 0.35)
        property variant fromTex: win.front
        property variant toTex: win.back
        fragmentShader: Qt.resolvedUrl("../../shaders/inkwipe.frag.qsb")
    }

    NumberAnimation {
        id: wipe
        target: ink
        property: "progress"
        from: 0
        to: 1
        duration: Motion.d(900)
        easing.type: Easing.InOutQuad   // even growth: the blot is seen spreading, not just appearing
        onFinished: win.finish()
    }
}
