pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// 滑 Fluido card (mockup 02, mock.css .flow / .fhk / .seg.x; docs/02-DISENO §Engawa): full width under 忍/鬼, radius 16,
// padding 10/12/12. Row 1 (44 px): hanko 滑 (off: accent outline; on: accent fill, glow, three speed lines on its left),
// «Fluido» + status line (⚠ when base × m ≠ Hz), switch, chevron to the page. Row 2: ×2 · ×4 · ×6 · «A medida» with its
// target. Tapping the card switches it; the segmented control changes the mode live (lsfg-vk reloads, no cut).
// Switching on sweeps a light across the hanko once (450 ms).
Item {
    id: root
    signal openPage
    readonly property bool on: Nameraka.wanted
    readonly property bool usable: Nameraka.available && !Nameraka.blocked && !Nameraka.batteryOff
    implicitHeight: col.implicitHeight + 10 + 12

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: area.containsMouse && !root.on ? Theme.colors.surface2 : Theme.colors.surface1
        border.width: 1
        border.color: root.on ? Theme.mix(Theme.colors.accent, Theme.colors.outline, 0.7) : Theme.colors.outline
        gradient: root.on ? onGradient : null
        Gradient {
            id: onGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.mix(Theme.colors.accent, Theme.colors.surface1, 0.83) }
            GradientStop { position: 0.75; color: Theme.colors.surface1 }
        }
        clip: true
        Kanji {
            x: parent.width - 108 - implicitWidth
            y: 7
            text: "滑"
            size: 42
            color: root.on ? Theme.colors.accent : Theme.colors.text
            opacity: root.on ? 0.10 : 0.06
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.usable ? Nameraka.toggle() : root.openPage()
    }

    ColumnLayout {
        id: col
        x: 12
        y: 10
        width: parent.width - 24
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 11
            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                // three speed lines on the left of the lit hanko (2 px, accent at 30 %)
                Column {
                    visible: root.on
                    anchors.right: hanko.left
                    anchors.rightMargin: 2
                    y: 12
                    spacing: 5
                    Repeater {
                        model: [6, 9, 5]          // inside the 12 px padding (the card clips in the mockup)
                        delegate: Rectangle {
                            required property var modelData
                            anchors.right: parent.right
                            width: modelData
                            height: 2
                            radius: 1
                            color: Theme.colors.accent
                            opacity: 0.3
                        }
                    }
                }
                SoftShadow {
                    visible: root.on
                    target: hanko
                    offsetY: 0
                    blur: 18
                    color: Theme.alpha(Theme.colors.accent, 0.45)
                }
                Rectangle {
                    id: hanko
                    anchors.fill: parent
                    radius: 10
                    color: root.on ? Theme.colors.accent : "transparent"
                    border.width: 1.5
                    border.color: root.on ? Theme.alpha(Theme.colors.onImage, 0.22) : Theme.colors.accent
                    clip: true
                    Kanji {
                        anchors.centerIn: parent
                        text: "滑"
                        brush: true
                        size: 22
                        color: root.on ? Theme.colors.surface0 : Theme.colors.accent
                    }
                    // the light sweep when it switches on (once)
                    Rectangle {
                        id: sweep
                        width: 14
                        height: parent.height * 1.6
                        y: -parent.height * 0.3
                        x: -width
                        rotation: 18
                        opacity: 0
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: Theme.alpha(Theme.colors.onImage, 0.55) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    ParallelAnimation {
                        id: sweepAnim
                        NumberAnimation { target: sweep; property: "x"; from: -sweep.width; to: hanko.width; duration: Motion.d(450); easing.type: Easing.InOutCubic }
                        SequentialAnimation {
                            NumberAnimation { target: sweep; property: "opacity"; from: 0; to: 1; duration: Motion.d(120) }
                            PauseAnimation { duration: Motion.d(210) }
                            NumberAnimation { target: sweep; property: "opacity"; to: 0; duration: Motion.d(120) }
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                OText {
                    text: "Nameraka"
                    size: 13.5
                    font.weight: Font.DemiBold
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    OText {
                        Layout.fillWidth: true
                        text: Nameraka.subtitle
                        size: 11.5
                        tabular: true
                        color: Theme.colors.textMuted
                        elide: Text.ElideRight
                    }
                    OIcon {
                        visible: Nameraka.warning !== ""
                        icon: "warning"
                        size: 14
                        color: Theme.colors.warning
                        Accessible.role: Accessible.StaticText
                        Accessible.name: Nameraka.warning
                    }
                }
            }
            Switch_ {
                checked: root.on
                enabled: root.usable || root.on
                label: "Nameraka"
                onToggled: Nameraka.toggle()
            }
            // chevron to the page: a bare icon like the mockup, focusable as a button
            Rectangle {
                implicitWidth: 18             // the icon's own size (layout unchanged); the ring sits 4 px outside
                implicitHeight: 18
                radius: 4
                color: "transparent"
                OIcon {
                    anchors.centerIn: parent
                    icon: "chevron_right"
                    size: 18
                    color: Theme.colors.textDim
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPage()
                }
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Ajustes de Nameraka"
                Keys.onReturnPressed: root.openPage()
                Keys.onSpacePressed: root.openPage()
                Keys.onRightPressed: root.openPage()
                FocusRing {}
            }
        }
        Segmented {
            Layout.fillWidth: true
            accent: true
            opacity: root.usable ? 1 : 0.45
            enabled: root.usable
            current: Settings.data.nameraka.mode
            options: [
                { id: "x2", label: "×2" }, { id: "x4", label: "×4" }, { id: "x6", label: "×6" },
                { id: "custom", icon: "tune", label: Nameraka.targetFps + " fps" }
            ]
            onPicked: id => Nameraka.setMode(id)
        }
    }

    onOnChanged: if (on && Motion.enabled) sweepAnim.restart()
    Accessible.role: Accessible.Button
    Accessible.name: "Nameraka (vídeo fluido), " + Nameraka.subtitle + (on ? ", activo" : "")
}
