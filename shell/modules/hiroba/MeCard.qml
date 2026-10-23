pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.modules.hiroba
import qs.components
import qs.services

// 広場 · you: hanko avatar (~/.face if it exists, else the profile kanji or your initial), greeting by the hour in
// Japanese and Spanish, name, time since boot, and lock · log out · settings · power (log out and power go through
// Dengen: they still need the 1,2 s hold).
HbCard {
    id: root
    readonly property var greet: {
        const h = Time.now.getHours();
        for (const g of (Glossary.g.greetings?.byHour ?? []))
            if (g.from < g.to ? (h >= g.from && h < g.to) : (h >= g.from || h < g.to))
                return g;
        return { jp: "こんにちは", es: "Hola" };
    }
    readonly property string seal: (Settings.data.profile?.kanji ?? "") !== "" ? Settings.data.profile.kanji
        : (Lock.userName || "?").charAt(0).toUpperCase()
    property real upSeconds: 0
    function uptimeText(): string {
        const m = Math.floor(upSeconds / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        return "encendido " + (d > 0 ? d + " d " + (h % 24) + " h" : h > 0 ? h + " h " + (m % 60) + " min" : m + " min");
    }
    FileView {
        id: up
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.upSeconds = parseFloat(text().split(" ")[0]) || 0
    }
    Connections {
        target: Time
        function onMinuteTick() { up.reload(); }
    }
    Component.onCompleted: up.reload()

    function act(f: var): void {
        Panels.close();
        f();
    }

    readonly property bool anime: Settings.data.hiroba.anime
    property string host: Quickshell.env("HOSTNAME") ?? ""
    // ~/.face only if it exists (an Image on a missing file warns on every open; the picture is not read here)
    property bool hasFace: false
    Process {
        running: true
        command: ["test", "-f", Paths.home + "/.face"]
        onExited: code => root.hasFace = code === 0
    }
    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: if (root.host === "") root.host = text().trim()
    }

    // ── anime (mockup 16): the greeting in a manga speech bubble coming out of your seal ───────────
    Item {
        anchors.fill: parent
        visible: root.anime
        Screentone {}
        // bubble: white, red offset shadow, a tail pointing down-left to the seal
        Item {
            id: bubble
            x: 76
            y: 14
            // the 2×2 actions sit below it (bottom right): the bubble may use the whole width
            width: Math.min(root.width - x - 14, bubbleCol.implicitWidth + 26)
            height: bubbleCol.implicitHeight + 16
            Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; radius: 16; color: Theme.colors.accent }
            Rectangle { anchors.fill: parent; radius: 16; color: Theme.colors.paper }
            Shape {
                x: -8
                y: parent.height - 26
                width: 12
                height: 14
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.colors.paper
                    startX: 9; startY: 0
                    PathLine { x: 0; y: 10 }
                    PathLine { x: 12; y: 8 }
                    PathLine { x: 9; y: 0 }
                }
            }
            Column {
                id: bubbleCol
                x: 13
                y: 8
                spacing: 2
                OText { text: root.greet.jp + "、" + Lock.userName + "！"; font.family: Theme.font.jp; font.weight: Font.Bold; size: 14; color: Theme.colors.paperInk }
                OText { text: root.uptimeText(); size: 11; color: Theme.colors.paperMuted; tabular: true }
            }
        }
        // seal with a red ring, resting on the card's bottom edge
        Rectangle {
            id: seal2
            x: 16
            y: root.height - height - 12
            width: 66
            height: 66
            radius: 22
            color: "transparent"
            border.width: 2
            border.color: Theme.colors.accent
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.colors.accentHover }
                    GradientStop { position: 0.5; color: Theme.colors.accent }
                    GradientStop { position: 1; color: Theme.mix(Theme.colors.accent, "#000000", 0.3) }
                }
                Kanji {
                    anchors.centerIn: parent
                    visible: face2.status !== Image.Ready
                    text: root.seal
                    brush: true
                    size: 30
                    color: Theme.colors.accentInk
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 18
                    visible: face2.status === Image.Ready
                    color: "transparent"
                    Image { id: face2; anchors.fill: parent; source: root.hasFace ? Paths.url(Paths.home + "/.face") : ""; sourceSize: Qt.size(120, 120); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
            }
            Rectangle { x: parent.width - 13; y: parent.height - 13; width: 14; height: 14; radius: 7; color: Theme.colors.success; border.width: 3; border.color: Theme.colors.island }
        }
        Column {
            x: 96
            y: seal2.y + 10
            width: actions2.x - x - 8         // never under the actions
            spacing: 2
            OText { width: parent.width; elide: Text.ElideRight; text: Lock.userName; size: 22; font.weight: Font.DemiBold; color: Theme.colors.islandText }
            OText { width: parent.width; elide: Text.ElideRight; text: Quickshell.env("USER") + "@" + root.host; size: 12; color: Theme.colors.islandDim }
        }
        // the four actions in a 2×2 grid on the right: lock · log out / settings · power
        Grid {
            id: actions2
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            columns: 2
            spacing: 6
            Repeater {
                model: [{ i: "lock", l: "Bloquear", f: () => Lock.lock() },
                        { i: "logout", l: "Cerrar sesión", f: () => { Dengen.show(); Dengen.selected = 2; } },
                        { i: "settings", l: "Ajustes", f: () => Settei.show("") },
                        { i: "power_settings_new", l: "Apagar…", red: true, f: () => Dengen.show() }]
                delegate: Rectangle {
                    id: b2
                    required property var modelData
                    width: 32
                    height: 32
                    radius: 11
                    color: modelData.red ? Theme.alpha(Theme.colors.accent, a2.containsMouse ? 0.3 : 0.18)
                        : a2.containsMouse ? Theme.colors.islandHover : Theme.colors.islandRest
                    OIcon { anchors.centerIn: parent; icon: b2.modelData.i; size: 17; color: b2.modelData.red ? Theme.colors.accent : Theme.colors.islandText }
                    MouseArea { id: a2; anchors.fill: parent; anchors.margins: -2; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.act(b2.modelData.f) }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.l
                }
            }
        }
    }

    // ── classic ─────────────────────────────────────────────────────────────────────────────────
    ColumnLayout {
        visible: !root.anime
        anchors.fill: parent
        anchors.margins: 18
        anchors.bottomMargin: 16
        spacing: 12
        RowLayout {
            spacing: 14
            Item {
                implicitWidth: 58
                implicitHeight: 58
                Rectangle {
                    id: hanko
                    anchors.fill: parent
                    radius: 18
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Theme.colors.accentHover }
                        GradientStop { position: 0.5; color: Theme.colors.accent }
                        GradientStop { position: 1; color: Theme.mix(Theme.colors.accent, "#000000", 0.3) }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: "transparent"
                        border.width: 1.5
                        border.color: Theme.alpha(Theme.colors.accentInk, 0.22)
                    }
                    Kanji {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: root.seal
                        brush: true
                        size: 30
                        color: Theme.colors.accentInk
                    }
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 18
                    visible: face.status === Image.Ready
                    color: "transparent"
                    Image {
                        id: face
                        anchors.fill: parent
                        source: root.hasFace ? Paths.url(Paths.home + "/.face") : ""
                        sourceSize: Qt.size(120, 120)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Rectangle {           // online dot
                    x: parent.width - 11
                    y: parent.height - 11
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.colors.success
                    border.width: 3
                    border.color: Theme.colors.island
                }
            }
            ColumnLayout {
                spacing: 2
                OText { text: root.greet.jp + " · " + root.greet.es.toLowerCase(); font.family: Theme.font.jp; size: 13; color: Theme.colors.islandMuted }
                OText { text: Lock.userName; size: 22; font.weight: Font.DemiBold; color: Theme.colors.islandText }
                OText { text: root.uptimeText(); size: 12; color: Theme.colors.islandDim; tabular: true }
            }
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            spacing: 8
            Repeater {
                model: [{ i: "lock", l: "Bloquear", f: () => Lock.lock() },
                        { i: "logout", l: "Cerrar sesión", f: () => { Dengen.show(); Dengen.selected = 2; } },
                        { i: "settings", l: "Ajustes", f: () => Settei.show("") },
                        { i: "power_settings_new", l: "Apagar…", red: true, f: () => Dengen.show() }]
                delegate: Rectangle {
                    id: b
                    required property var modelData
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 13
                    color: modelData.red ? Theme.alpha(Theme.colors.accent, area.containsMouse ? 0.3 : 0.18)
                        : area.containsMouse ? Theme.colors.islandHover : Theme.colors.islandRest
                    Behavior on color { CAnim {} }
                    scale: area.pressed ? 0.94 : 1
                    Behavior on scale { Anim { ms: Motion.micro } }
                    OIcon {
                        anchors.centerIn: parent
                        icon: b.modelData.i
                        size: 20
                        color: b.modelData.red ? Theme.colors.accent : Theme.colors.islandText
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.act(b.modelData.f)
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.l
                }
            }
        }
    }
}
