import QtQuick
import qs.config

// Settings card (mock.css .card): surface1, 1 px outline, radius 16. Rows stack inside (Column → each SRow knows
// its index for the separator).
Rectangle {
    id: root
    default property alias rows: col.data
    property real padTop: 0
    property real padBottom: 0
    width: parent ? parent.width : implicitWidth
    implicitHeight: col.implicitHeight + padTop + padBottom
    radius: Theme.radius.card
    color: Theme.colors.surface1
    border.width: 1
    border.color: Theme.colors.outline
    Column {
        id: col
        y: root.padTop
        width: root.width
    }
}
