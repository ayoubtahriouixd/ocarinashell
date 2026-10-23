pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components

// One Dengen card (mockup 05: 168×212, radius 26, brush kanji 86, keycap top-right). Selected = red lacquer, lifted
// 8 px with a red glow; while held, sumi ink rises inside and the bar fills (1.2 s).
Item {
    id: root

    required property var action
    property bool selected: false
    property real hold: 0                  // 0–1 while held
    property bool badge: false             // 新: an update is waiting
    signal activated()
    signal pressedDown()
    signal released()
    signal hovered()

    width: 168
    height: 212

    // red glow under the selected card (box-shadow 0 22px 50px rgba(230,0,51,.45)): one MultiEffect, only when selected
    MultiEffect {
        source: glowSource
        anchors.fill: card
        visible: root.selected
        opacity: lift.value
        shadowEnabled: true
        // CSS blur radius 50 ≈ MultiEffect blurMax 64; Qt's shadow is denser than the browser's: α .22 measures like .45
        shadowColor: Theme.alpha(Theme.colors.accent, 0.22)
        shadowBlur: 1.0
        shadowVerticalOffset: 22
        blurMax: 64
        autoPaddingEnabled: true
    }
    Rectangle {
        id: glowSource
        anchors.fill: card
        radius: 26
        color: "black"
        visible: false
        layer.enabled: root.selected
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.topMargin: -8 * lift.value
        anchors.bottomMargin: 8 * lift.value
        radius: 26
        clip: true
        color: Theme.alpha(Theme.colors.surface1, 0.82)
        border.width: root.selected ? 0 : 1
        border.color: hover.containsMouse ? Theme.colors.outlineStrong : Theme.colors.outline

        // red lacquer: linear-gradient(160deg, #ff1f4f, #e60033 45%, #a3001f)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: lift.value
            visible: opacity > 0
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.colors.accentHover }
                GradientStop { position: 0.45; color: Theme.colors.accent }
                GradientStop { position: 1.0; color: Theme.mix(Theme.colors.accent, "#000000", 0.29) }
            }
            // inset 0 1px 0 rgba(255,255,255,.25)
            Rectangle {
                anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                width: parent.width - 2 * parent.radius
                height: 1
                color: "#40ffffff"
            }
        }
        // 墨 ink rising while held (soft top edge, like ink soaking up paper)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: (parent.height + 40) * root.hold
            // a straight, soft level; rounded only where it meets the card's bottom corners
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: parent.radius
            bottomRightRadius: parent.radius
            visible: root.hold > 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#002a0008" }
                GradientStop { position: Math.min(0.6, 40 / Math.max(1, (root.height + 40) * root.hold)); color: "#592a0008" }
                GradientStop { position: 1.0; color: "#6b2a0008" }
            }
        }

        Kbd {
            anchors { top: parent.top; right: parent.right; margins: 14 }
            text: root.action.key
        }
        Rectangle {
            visible: root.badge
            anchors { top: parent.top; left: parent.left; margins: 14 }
            height: 20
            width: 26
            radius: 10
            color: root.selected ? "#33ffffff" : Theme.colors.surface3
            Kanji {
                anchors.centerIn: parent
                text: "新"
                size: 12
                color: root.selected ? "#ffffff" : Theme.colors.text
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 14
            Kanji {
                anchors.horizontalCenter: parent.horizontalCenter
                brush: true
                text: root.action.kanji
                size: 86
                font.weight: Font.Normal
                color: root.selected ? "#ffffff" : Theme.colors.text
                renderType: Text.CurveRendering
                // CSS line-height:1 — the brush font's own line box is much taller
                lineHeightMode: Text.FixedHeight
                lineHeight: 86
                height: 86
            }
            OText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.action.label
                size: 14
                font.weight: Font.Medium
                color: root.selected ? "#d9ffffff" : Theme.colors.textMuted
            }
        }

        // hold bar (destructive actions, selected)
        Rectangle {
            visible: root.selected && root.action.destructive
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 16 }
            height: 4
            radius: 2
            color: "#40ffffff"
            Rectangle {
                width: parent.width * root.hold
                height: parent.height
                radius: 2
                color: "#ffffff"
            }
        }
    }

    // 0 → 1 when selected (lift, lacquer, glow)
    QtObject {
        id: lift
        property real value: root.selected ? 1 : 0
        Behavior on value { Anim { ms: Motion.fast } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onPressed: root.pressedDown()
        onReleased: root.released()
        onCanceled: root.released()
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.action.label + (root.action.destructive ? " (mantén pulsado)" : "")
}
