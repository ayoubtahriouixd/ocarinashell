pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.obi
import qs.components
import qs.services

// Obi content (mockup 01, docs/02-DISENO §5): brand · workspaces · focused title … tray · status cluster · bell.
Item {
    id: root

    required property string screenName
    property real glassAlpha: Theme.glassOpaqueAlpha
    property real dpr: 1.75
    property bool square: false              // bar.style "attached": edge to edge, no rounding, line underneath
    property bool isles: false               // bar.style "isles" (mockup 15): no bar, two glass capsules
    readonly property alias leftCap: capL
    readonly property alias rightCap: capR

    // glass: surface0 at 72 % (blurred by niri) + 1 px border + 1 px inner highlight on top
    Rectangle {
        id: glass
        visible: !root.isles
        anchors.fill: parent
        radius: root.square ? 0 : Theme.radius.bar
        color: Theme.alpha(Theme.colors.surface0, root.glassAlpha)
        Rectangle {
            anchors.fill: parent
            visible: !root.square
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.colors.glassBorder
        }
        Rectangle {
            visible: root.square
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.colors.outline
        }
        Rectangle {
            visible: !root.square
            x: Theme.radius.bar
            y: 1
            width: parent.width - 2 * Theme.radius.bar
            height: 1
            color: Theme.colors.glassHighlight
        }
    }

    // 島々 isles: one glass capsule behind each group (mock.css .obi.isles .cap): surface0 62 %, 1 px text 9 % border,
    // a light line on top and a dark one below; radius = half the height. They follow the groups' real width.
    component Capsule: Rectangle {
        property Item group
        visible: root.isles && group !== null && group.width > 0
        // the capsule drifts WITH its icons (保護 Hogo moves the content 2 px every 15 min): a still glass around
        // moving icons read as off-centre
        y: 1 + Hogo.dy
        height: parent.height - 2
        radius: height / 2
        // light themes: 62 % white over a dark wallpaper turned mid-grey with ~2,6:1 text (visual QA fase 17): ≥ 88 %
        color: Theme.alpha(Theme.colors.surface0, root.glassAlpha < 0.9 ? (Theme.dark ? 0.62 : 0.88) : Theme.glassOpaqueAlpha)
        border.width: 1
        border.color: Theme.alpha(Theme.colors.text, 0.09)
        Rectangle {
            x: parent.radius; y: 1; width: parent.width - 2 * parent.radius; height: 1
            color: Theme.alpha("#ffffff", 0.09)
        }
        Rectangle {
            x: parent.radius; y: parent.height - 2; width: parent.width - 2 * parent.radius; height: 1
            color: Theme.alpha("#000000", 0.25)
        }
    }
    Capsule {
        id: capL
        group: leftGroup
        x: content.x + row.x + leftGroup.x - 12          // content.x already carries Hogo.dx
        width: leftGroup.width + 12 + 13
    }
    Capsule {
        id: capR
        group: rightGroup
        x: content.x + row.x + rightGroup.x - 4          // the status cluster carries its own 10 px of padding
        width: rightGroup.width + 4 + 6
    }

    // Hogo: the content moves and fades, the glass and the exclusive zone stay put
    Item {
        id: content
        width: parent.width
        height: parent.height
        x: Hogo.dx
        y: Hogo.dy
        opacity: Hogo.dimmed && !hover.hovered ? 0.8 : 1
        Behavior on opacity { Anim { ms: Motion.ambient } }

        RowLayout {
            id: row
            anchors.fill: parent
            // isles: each capsule touches the window edge (capL.x = 0, capR ends at the width), so both sit at the
            // same 10 px from the screen edges as mockup 15 (visual QA fase 17: they were 12 and 19)
            anchors.leftMargin: Theme.bar.padLeft
            anchors.rightMargin: root.isles ? Theme.bar.padRight - 2 : Theme.bar.padRight + 1
            spacing: Theme.bar.gap

            RowLayout {
            id: leftGroup
            spacing: Theme.bar.gap
            Layout.fillWidth: false
            Layout.maximumWidth: row.width * 0.45
            // オカリナ the mark is a button: click → 器 the app drawer (AppDrawer, Ayoub fase 16). The ocarina «plays»
            // when pressed: it tilts on a spring, a red ripple leaves the pill and two notes float off its holes.
            // Its hover pill is the same 30 px one as the bell's, so both ends of the bar answer alike.
            Rectangle {
                id: brand
                Layout.preferredWidth: 46
                Layout.preferredHeight: 30
                Layout.leftMargin: root.isles ? -5 : 0      // the pill, not the mark, meets the capsule's padding
                Layout.alignment: Qt.AlignVCenter
                radius: root.isles ? 15 : Theme.radius.control
                color: brandArea.containsMouse || drawer.shown ? Theme.colors.surface2 : "transparent"
                Behavior on color { CAnim {} }
                Accessible.role: Accessible.Button
                Accessible.name: "Aplicaciones"
                Accessible.onPressAction: brand.play()

                function play(): void {
                    drawer.toggle();
                    if (Motion.enabled && !drawer.closing)
                        tune.restart();
                }

                // the ripple
                Rectangle {
                    id: ripple
                    anchors.centerIn: parent
                    width: parent.height
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.colors.accent
                    opacity: 0
                    scale: 0.6
                }
                Image {
                    id: mark
                    anchors.centerIn: parent
                    width: 36
                    height: 21
                    // 忍 Shinobi: the mono mark in the theme's muted grey (mockup 06; a static file, no recolouring)
                    source: Paths.url(Paths.asset("logo/svg/ocarinashell-mark-" + (Modes.shinobi ? "shinobi" : "flat") + ".svg"))
                    sourceSize: Qt.size(36 * root.dpr, 21 * root.dpr)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    transformOrigin: Item.Center
                }
                // two notes off the holes (they stay inside the bar's height: a layer surface clips the rest)
                Repeater {
                    model: [{ g: "♪", dx: 10, dy: -9, delay: 0 }, { g: "♫", dx: 19, dy: -4, delay: 110 }]
                    delegate: OText {
                        id: note
                        required property var modelData
                        x: brand.width / 2 + 4
                        y: brand.height / 2 - 8
                        text: modelData.g
                        size: 11
                        font.weight: Font.Bold
                        color: Theme.colors.accent
                        opacity: 0
                        SequentialAnimation {
                            id: noteAnim
                            PauseAnimation { duration: Motion.d(note.modelData.delay) }
                            ParallelAnimation {
                                Anim { target: note; property: "opacity"; from: 0; to: 1; ms: Motion.micro }
                                Anim { target: note; property: "x"; from: brand.width / 2 + 4; to: brand.width / 2 + 4 + note.modelData.dx; ms: Motion.emphasized; easing.bezierCurve: Motion.decel }
                                Anim { target: note; property: "y"; from: brand.height / 2 - 8; to: brand.height / 2 - 8 + note.modelData.dy; ms: Motion.emphasized; easing.bezierCurve: Motion.decel }
                            }
                            Anim { target: note; property: "opacity"; to: 0; ms: Motion.base }
                        }
                        Connections {
                            target: tune
                            function onStarted(): void { noteAnim.restart(); }
                        }
                    }
                }
                SequentialAnimation {
                    id: tune
                    ParallelAnimation {
                        // tilt like a note blown into it, then settle on a spring
                        SequentialAnimation {
                            Anim { target: mark; property: "rotation"; to: -14; ms: Motion.micro }
                            SpringAnimation { target: mark; property: "rotation"; to: 0; spring: 5; damping: 0.18; epsilon: 0.2 }
                        }
                        SequentialAnimation {
                            Anim { target: mark; property: "scale"; to: 0.86; ms: Motion.micro }
                            SpringAnimation { target: mark; property: "scale"; to: 1; spring: 6; damping: 0.25; epsilon: 0.005 }
                        }
                        ParallelAnimation {
                            Anim { target: ripple; property: "opacity"; from: 0.7; to: 0; ms: Motion.slow + 80 }
                            Anim { target: ripple; property: "scale"; from: 0.6; to: 1.7; ms: Motion.slow + 80; easing.bezierCurve: Motion.decel }
                        }
                    }
                }
                MouseArea {
                    id: brandArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: brand.play()
                }
                AppDrawer {
                    id: drawer
                    anchorItem: brand
                }
                Connections {
                    target: Apps
                    function onToggleRequested(screen: string): void {
                        if (screen === root.screenName || screen === "")
                            brand.play();
                    }
                }
            }
            // bar.modules (Settei → Barra e isla): which modules and in what order (left and right groups are fixed).
            // The modules live once, outside the layout; LayoutItemProxy places them in the chosen order.
            Repeater {
                model: root.leftMods
                delegate: RowLayout {
                    id: lm
                    required property string modelData
                    // no focused window → no title and no separator: the capsule hugs the workspaces like the right
                    // one hugs its icons (Ayoub: the left isle has to match the island and the right isle)
                    visible: modelData !== "title" || title.win !== null
                    Layout.fillWidth: modelData === "title"
                    Layout.maximumWidth: modelData === "title" ? 360 + Theme.bar.gap + 1 : -1
                    spacing: Theme.bar.gap
                    Separator {}
                    LayoutItemProxy {
                        target: lm.modelData === "workspaces" ? ws : title
                    }
                }
            }
            }
            Item {
                Layout.fillWidth: true
            }
            RowLayout {
                id: rightGroup
                Layout.fillWidth: false        // nested layouts fill by default: hug the modules
                spacing: root.isles ? 0 : 6    // mock.css .obi .right { gap: 6px }; isles: the hover pills touch
                Repeater {
                    model: root.rightMods
                    delegate: RowLayout {
                        id: rm
                        required property string modelData
                        visible: modelData !== "tray" || tray.count > 0     // an empty tray takes no room
                        spacing: root.isles ? 2 : 6
                        // 船 Fune: the VM indicator sits right before the status cluster (mockup 09); without the
                        // cluster in the bar, before the bell. Created only where and while it shows.
                        // 蛇 Snake loaded (mockup 11): first of the indicators, right after the tray
                        Loader {
                            id: snake
                            active: fune.here && Snake.shown
                            visible: active
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: root.isles ? 4 : 0
                            Layout.rightMargin: root.isles ? 4 : 0
                            sourceComponent: SnakeIndicator {}
                        }
                        Separator {
                            visible: snake.active && !news.active && !fune.active
                        }
                        // 新 updates / reboot waiting (mockup 05): same place as 船, before it
                        Loader {
                            id: news
                            active: fune.here && Updates.show
                            visible: active
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: root.isles ? 4 : 0
                            Layout.rightMargin: root.isles ? 4 : 0
                            sourceComponent: UpdateIndicator {}
                        }
                        Separator {
                            visible: news.active && !fune.active
                        }
                        Loader {
                            id: fune
                            readonly property bool here: rm.modelData === "cluster"
                                                         || (rm.modelData === "bell" && root.rightMods.indexOf("cluster") < 0)
                            active: here && (Fune.on || Fune.waking)
                            visible: active
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: root.isles ? 4 : 0    // off the capsule's round end (mockup .ind)
                            Layout.rightMargin: root.isles ? 4 : 0
                            sourceComponent: FuneIndicator {}
                        }
                        Separator {
                            visible: fune.active
                        }
                        LayoutItemProxy {
                            target: rm.modelData === "tray" ? tray : rm.modelData === "cluster" ? cluster : bell
                        }
                        Separator {
                            // the 船 indicator brings its own separator when it follows the tray directly
                            visible: rm.modelData === "tray" && tray.count > 0
                                     && !((Fune.on || Fune.waking || Updates.show) && root.rightMods[root.rightMods.indexOf("tray") + 1] === "cluster")
                        }
                    }
                }
            }
        }
        Workspaces { id: ws; screenName: root.screenName; visible: root.leftMods.indexOf("workspaces") >= 0 }
        FocusedTitle { id: title; Layout.fillWidth: true; Layout.maximumWidth: 360; visible: root.leftMods.indexOf("title") >= 0 }
        Tray { id: tray; visible: root.rightMods.indexOf("tray") >= 0 }
        StatusCluster { id: cluster; visible: root.rightMods.indexOf("cluster") >= 0 }
        Bell { id: bell; visible: root.rightMods.indexOf("bell") >= 0 }
    }
    readonly property var mods: (Settings.data.bar.modules ?? []).filter((m, i, a) => a.indexOf(m) === i)
    readonly property var leftMods: mods.filter(m => m === "workspaces" || m === "title")
    readonly property var rightMods: mods.filter(m => m === "tray" || m === "cluster" || m === "bell")

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) Hogo.activity()
    }
    onDprChanged: Hogo.scale = dpr
    Component.onCompleted: Hogo.scale = dpr
}
