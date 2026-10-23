pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.modules.obi
import qs.components

// System tray (StatusNotifierItem): dimmed 17 px icons. Left click activates (or opens the menu if the item only
// has a menu), right click opens our themed menu, wheel scrolls.
RowLayout {
    id: root
    spacing: 8
    readonly property int count: SystemTray.items.values.length
    visible: count > 0
    Layout.leftMargin: 4
    Layout.rightMargin: 4

    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: ti
            required property SystemTrayItem modelData
            Layout.preferredWidth: 17
            Layout.preferredHeight: 17
            opacity: ma.containsMouse ? 1 : 0.8
            Accessible.role: Accessible.Button
            Accessible.name: ti.modelData.tooltipTitle || ti.modelData.title || ti.modelData.id

            IconImage {
                anchors.fill: parent
                source: ti.modelData.icon
                implicitSize: 17
                asynchronous: true
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                anchors.margins: -6          // comfortable touch target
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        ti.modelData.secondaryActivate();
                    else if (mouse.button === Qt.RightButton || ti.modelData.onlyMenu)
                        menu.open();
                    else
                        ti.modelData.activate();
                }
                onWheel: w => ti.modelData.scroll(w.angleDelta.y / 120, false)
            }
            TrayMenu {
                id: menu
                anchorItem: ti
                handle: ti.modelData.hasMenu ? ti.modelData.menu : null
            }
        }
    }
}
