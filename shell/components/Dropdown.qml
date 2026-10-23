pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Drop-down (mock.css .drop): 34 px, surface0, 1 px outlineStrong, current label + expand_more. The menu is created
// on the window's root item (so it is never clipped by a card or a Flickable), opens below (or above when there is
// no room), closes with Esc, a click outside or a pick. options: [{ id, label, sub? }].
Rectangle {
    id: root
    property var options: []
    property var current: null
    property string label: "Desplegable"
    property real menuWidth: Math.max(width, 180)
    signal picked(var id)

    readonly property var currentOption: options.find(o => o.id === current) ?? null
    implicitHeight: 34
    implicitWidth: Math.max(80, row.implicitWidth + 24)
    radius: 10
    color: area.containsMouse ? Theme.colors.surface2 : Theme.colors.surface0
    border.width: 1
    border.color: Theme.colors.outlineStrong
    Behavior on color { CAnim {} }
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: label + ": " + (currentOption?.label ?? "")
    Keys.onReturnPressed: open()
    Keys.onSpacePressed: open()
    // arrows open the menu (choosing needs Enter): moving through a page must never change a setting by accident
    Keys.onDownPressed: open()
    Keys.onUpPressed: open()
    function step(d: int): void {
        const i = options.findIndex(o => o.id === current);
        const n = options[Math.max(0, Math.min(options.length - 1, i + d))];
        if (n && n.id !== current)
            picked(n.id);
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8
        OText {
            Layout.fillWidth: true
            text: root.currentOption?.label ?? "—"
            size: 13
            tabular: true
        }
        OIcon {
            icon: "expand_more"
            size: 18
            color: Theme.colors.textMuted
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
    }
    FocusRing {}

    property Item menu: null
    function open(): void {
        if (menu) {
            menu.destroy();
            menu = null;
            return;
        }
        let top = root;
        while (top.parent)
            top = top.parent;
        menu = menuComp.createObject(top, { host: top });
    }
    Component.onDestruction: if (menu) menu.destroy()

    Component {
        id: menuComp
        MouseArea {
            id: shade
            required property Item host
            anchors.fill: parent
            z: 1000
            onClicked: close()
            onWheel: w => w.accepted = true
            function close(): void {
                root.menu = null;
                destroy();
                root.forceActiveFocus();
            }
            readonly property point origin: root.mapToItem(host, 0, 0)
            readonly property real listH: Math.min(list.contentHeight + 12, 320)
            readonly property bool above: origin.y + root.height + 6 + listH > host.height - 8
            property int hi: Math.max(0, root.options.findIndex(o => o.id === root.current))

            SoftShadow {
                target: box
                offsetY: 8
                blur: 24
                opacity: box.opacity
                color: Theme.alpha(Theme.colors.shadow, 0.35)
            }
            Rectangle {
                id: box
                x: Math.min(shade.origin.x + root.width - width, shade.host.width - width - 8)
                y: shade.above ? shade.origin.y - height - 6 : shade.origin.y + root.height + 6
                width: root.menuWidth
                height: shade.listH
                radius: Theme.radius.menu
                color: Theme.colors.surface0
                border.width: 1
                border.color: Theme.colors.outlineStrong
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { Anim { ms: Motion.fast } }
                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: root.options
                    currentIndex: shade.hi
                    focus: true
                    boundsBehavior: Flickable.StopAtBounds
                    Component.onCompleted: { positionViewAtIndex(currentIndex, ListView.Center); forceActiveFocus(); }
                    Keys.onEscapePressed: shade.close()
                    Keys.onReturnPressed: { root.picked(root.options[currentIndex].id); shade.close(); }
                    Keys.onUpPressed: shade.hi = Math.max(0, shade.hi - 1)
                    Keys.onDownPressed: shade.hi = Math.min(root.options.length - 1, shade.hi + 1)
                    delegate: Rectangle {
                        id: opt
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: modelData.sub ? 44 : 32
                        radius: 8
                        color: opt.index === shade.hi ? Theme.colors.surface2 : "transparent"
                        ColumnLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: check.left
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 2
                            OText {
                                Layout.fillWidth: true
                                text: opt.modelData.label
                                size: 13
                                tabular: true
                                font.weight: opt.modelData.id === root.current ? Font.DemiBold : Font.Normal
                            }
                            OText {
                                visible: !!opt.modelData.sub
                                Layout.fillWidth: true
                                text: opt.modelData.sub ?? ""
                                size: 11.5
                                color: Theme.colors.textMuted
                            }
                        }
                        OIcon {
                            id: check
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: opt.modelData.id === root.current
                            icon: "check"
                            size: 16
                            color: Theme.colors.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: shade.hi = opt.index
                            onClicked: { root.picked(opt.modelData.id); shade.close(); }
                        }
                    }
                }
            }
        }
    }
}
