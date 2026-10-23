import QtQuick
import qs.config

// The boot-chain ocarina (Plymouth's layers), playing exactly like assets/boot/plymouth/ocarinashell/ocarinashell.script
// once its entrance is over: holes fingered one after another every 4.2 s, waves breathing every 2.4 s, the hanko
// swapping ❯_ ⇄ 殻 every 9 s. `t` counts Plymouth frames (50 per second) and starts at `start`, so the farewell and the
// greeter show the same phase Plymouth would. Static (frame `start`) when `playing` is false or without Motion.
// Shared by modules/dengen/Farewell.qml and the greeter (greeter/Greeter.qml): `dir` holds the layer PNGs.
Item {
    id: root

    property string dir: ""
    property real start: 210
    property bool playing: true
    property real t: start
    property int sourcePx: 512               // decoded size of each layer (device pixels)

    // 25 steps a second, not every frame: the greeter may wait minutes for the password (on battery, at boot), and
    // the slowest change here is a 0.4 s fade — ten steps of it are indistinguishable from 48 at 120 Hz
    Timer {
        interval: 40
        repeat: true
        running: root.playing && Motion.enabled && root.visible
        onTriggered: root.t += 2                // Plymouth frames (50/s) per 40 ms
    }

    function hole(i: int): real {
        const ph = ((t - 75 - i * 22) % 210 + 210) % 210;
        return ph < 20 ? 0.35 + 0.65 * Math.abs(ph - 10) / 10 : 1;
    }
    function wave(i: int): real {
        return (0.72 + 0.28 * Math.cos((t - 75 - i * 15) * 2 * Math.PI / 120)) * (1 - 0.2 * i);
    }
    readonly property real kanji: {
        const ph = ((t - 120) % 450 + 450) % 450;
        return ph >= 213 && ph < 225 ? (ph - 213) / 12 : ph >= 225 && ph < 438 ? 1 : ph >= 438 ? 1 - (ph - 438) / 12 : 0;
    }

    component Layer: Image {
        anchors.fill: parent
        sourceSize: Qt.size(root.sourcePx, root.sourcePx)
        smooth: true
        mipmap: true
    }
    Layer { source: root.dir === "" ? "" : "file://" + root.dir + "/tile.png" }
    Layer { source: root.dir === "" ? "" : "file://" + root.dir + "/body.png" }
    Repeater {
        model: 6
        delegate: Layer {
            required property int index
            source: root.dir === "" ? "" : "file://" + root.dir + "/hole" + index + ".png"
            opacity: root.hole(index)
        }
    }
    Repeater {
        model: 2
        delegate: Layer {
            required property int index
            source: root.dir === "" ? "" : "file://" + root.dir + "/wave" + index + ".png"
            opacity: root.wave(index)
        }
    }
    Layer {
        source: root.dir === "" ? "" : "file://" + root.dir + "/seal-prompt.png"
        opacity: 1 - root.kanji
    }
    Layer {
        source: root.dir === "" ? "" : "file://" + root.dir + "/seal-kanji.png"
        opacity: root.kanji
        visible: opacity > 0
    }
}
