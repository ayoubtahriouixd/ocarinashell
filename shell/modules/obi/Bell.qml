import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Notification bell in its own hover pill (same 18 px filled glyph as the cluster); red dot with a ring in the
// capsule's colour when something is unread; No molestar = the «off» bell, dimmed.
Rectangle {
    id: root
    readonly property bool isles: Settings.data.bar.style === "isles"
    Layout.preferredWidth: 30
    Layout.preferredHeight: 30
    Layout.alignment: Qt.AlignVCenter
    radius: isles ? 15 : Theme.radius.control
    color: area.containsMouse ? Theme.colors.surface2 : "transparent"
    Behavior on color { CAnim {} }

    // the cluster's 20 px glyph slot (same device-pixel rounding, so the bell shares their centre line)
    Item {
        anchors.centerIn: parent
        width: 20
        height: 20
        OIcon {
            anchors.centerIn: parent
            icon: Notifs.dnd ? "notifications_off" : Notifs.unread > 0 ? "notifications_active" : "notifications"
            fill: true
            optical: true
            size: 18
            color: Notifs.dnd ? Theme.colors.textDim : Notifs.unread > 0 ? Theme.colors.text : Theme.colors.textMuted
        }
    }
    Rectangle {
        visible: Notifs.unread > 0 && !Notifs.dnd
        x: 18
        y: 5
        width: 8
        height: 8
        radius: 4
        color: Theme.colors.accent
        border.width: 2
        border.color: Theme.alpha(Theme.colors.surface0, 0.85)
    }
    Accessible.role: Accessible.Button
    Accessible.name: Notifs.unread > 0 ? "Notificaciones: " + Notifs.unread + " sin leer" : "Notificaciones"
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("notifications", "")
    }
}
