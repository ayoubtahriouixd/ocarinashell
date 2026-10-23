pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Workspaces as kanji numerals 一 二 三… The active one wears the red hanko, which slides with a spring to the new
// workspace (signature moment #1). Busy = muted + one dot per window (max 3); empty = dim; urgent = pulsing border.
// Wheel = previous/next, click = go, right click = rename (edited inside the island).
Item {
    id: root

    required property string screenName
    readonly property var list: Niri.workspacesOn(screenName)
    readonly property int activeIndex: Math.max(0, list.findIndex(w => w.is_active))
    readonly property real cell: Theme.bar.cell
    readonly property real gap: Theme.bar.cellGap
    // 島々 isles (mockup 15): the active workspace is a wider pill, the others stay square cells
    readonly property bool pill: Settings.data.bar.style === "isles"
    readonly property real extra: pill ? 8 : 0
    function cellX(i: int): real {
        return i * (cell + gap) + (pill && i > activeIndex ? extra : 0);
    }

    Layout.preferredWidth: list.length * cell + Math.max(0, list.length - 1) * gap + (list.length > 0 ? extra : 0)
    Layout.preferredHeight: cell
    Layout.alignment: Qt.AlignVCenter

    // ── the hanko (behind the cells) ─────────────────────────────────────────────────────────
    SoftShadow {
        target: hanko
        visible: root.list.length > 0
        offsetY: 3
        blur: 10
        steps: 6
        color: Theme.alpha(Theme.colors.accent, 0.3)
    }
    Rectangle {
        id: hanko
        visible: root.list.length > 0
        width: root.cell + root.extra
        height: root.cell
        radius: root.pill ? root.cell / 2 : Theme.radius.hanko
        x: root.cellX(root.activeIndex)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.colors.accentHover }
            GradientStop { position: 0.55; color: Theme.colors.accent }
            GradientStop { position: 1.0; color: Theme.mix(Theme.colors.accent, Theme.colors.bg, 0.1) }
        }
        // inner 1.5 px white rim at 18 %
        Rectangle {
            anchors.fill: parent
            anchors.margins: 0.75
            radius: parent.radius - 0.75
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.18)
        }
        Behavior on x {
            enabled: Motion.enabled
            SpringAnimation {
                spring: Motion.hanko.spring
                damping: Motion.hanko.damping
                epsilon: 0.25
            }
        }
    }

    Item {
        // model = count: cells stay alive across niri events (only their data changes), so colour behaviours
        // animate and nothing is rebuilt on every focus change
        Repeater {
            model: root.list.length
            delegate: Item {
                id: c
                required property int index
                readonly property var modelData: root.list[index] ?? ({ id: -1, idx: index + 1 })
                readonly property bool active: modelData.is_active ?? false
                readonly property int windows: Niri.windowCounts[modelData.id] ?? 0
                x: root.cellX(index)
                Behavior on x { enabled: Motion.enabled; SpringAnimation { spring: Motion.hanko.spring; damping: Motion.hanko.damping; epsilon: 0.25 } }
                width: root.cell + (active ? root.extra : 0)
                height: root.cell

                // named: its first character, uppercase (in the same mincho face as the numerals); else the numeral
                readonly property string first: c.modelData.name ? c.modelData.name.charAt(0) : ""
                Kanji {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    // numbered by position: the drop-down terminal's hidden workspace is left out (Niri.stashWs)
                    text: c.first !== "" ? c.first.toUpperCase() : Glossary.numeral(c.index + 1)
                    size: 15
                    color: c.active ? Theme.colors.accentInk : c.windows > 0 ? Theme.colors.textMuted : Theme.colors.textDim
                    opacity: c.active || c.windows > 0 ? 1 : 0.7
                    Behavior on color { CAnim {} }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    spacing: 2
                    Repeater {
                        model: Math.min(3, c.windows)
                        delegate: Rectangle {
                            width: 3
                            height: 3
                            radius: 2
                            color: c.active ? Theme.colors.accentInk : Theme.colors.textMuted
                            opacity: 0.75
                        }
                    }
                }

                // urgent: the border pulses while (and only while) the workspace is urgent
                Rectangle {
                    anchors.fill: parent
                    radius: root.pill ? root.cell / 2 : Theme.radius.hanko
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.colors.accent
                    visible: (c.modelData.is_urgent ?? false) && !c.active
                    SequentialAnimation on opacity {
                        running: (c.modelData.is_urgent ?? false) && !c.active && Motion.enabled
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.25; duration: Motion.d(Motion.page) }
                        NumberAnimation { from: 0.25; to: 1; duration: Motion.d(Motion.page) }
                        onRunningChanged: if (!running) parent.opacity = 1
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Espacio " + (c.modelData.name || (c.index + 1)) + (c.active ? ", activo" : "")
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3          // ≥ 32 px touch target without changing the look
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            Panels.startRename(c.modelData.id);
                        else
                            Niri.focusWorkspace(c.modelData.id);
                    }
                }
            }
        }
    }

    // wheel = previous / next workspace (accumulated: a touchpad flick is one step)
    WheelStep {
        onStep: dir => Niri.focusWorkspaceRelative(-dir)
    }
}
