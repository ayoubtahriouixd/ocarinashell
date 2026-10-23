import QtQuick
import qs.config
import qs.services

// Glass panel (mock.css .panel.glass.strong): surface0 at 86 % (blurred by niri behind) or 94 % without blur,
// 1 px glass border and 1 px top highlight, radius 22, soft shadow.
Item {
    id: root
    property real radius: Theme.radius.panel
    // 86 % only when the compositor blur is really behind it (PanelHostBlur loaded); otherwise the opaque fallback
    property real alpha: Panels.blurActive && Theme.blur && Theme.transparency
        ? 0.86 : Theme.glassOpaqueAlpha
    default property alias content: inner.data

    SoftShadow {
        target: bg
        offsetY: 14
        blur: 40
        color: Theme.alpha(Theme.colors.shadow, 0.45)
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: Theme.alpha(Theme.colors.surface0, root.alpha)
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.colors.glassBorder
    }
    Rectangle {
        x: root.radius
        y: 1
        width: parent.width - 2 * root.radius
        height: 1
        color: Theme.colors.glassHighlight
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
