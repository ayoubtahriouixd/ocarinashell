import QtQuick
import qs.config
import qs.services

// Keyboard focus outline: 2 px accent with 2 px gap (docs/02-DISENO §6), only for keyboard navigation.
Rectangle {
    readonly property Item target: parent
    // not after a click: a control that takes the focus on press sets `mouseFocus` (Item has no focusReason in
    // Qt 6.12); the ring is for finding your place with the keyboard
    visible: target && target.activeFocus && !(target.mouseFocus ?? false) && target !== Panels.quietFocus
    anchors.fill: parent
    anchors.margins: -4
    radius: (target && target.radius !== undefined ? target.radius : 10) + 4
    color: "transparent"
    border.width: 2
    border.color: Theme.colors.accent
}
