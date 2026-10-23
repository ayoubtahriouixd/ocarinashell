pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Segmented control (mock.css .seg): surface1 box with 4 px padding; the current option is surface3 with a 1 px
// highlight. options: [{ id, kanji (optional), icon (optional), label, chip (optional small tag), disabled }].
// accent (mock.css .seg.x, 滑 Fluido): surface0 at 55 % behind, tabular 13/600 labels, the current one in the accent
// with a 45 % accent rim.
Rectangle {
    id: root
    property var options: []
    property string current: ""
    property bool accent: false
    signal picked(string id)

    implicitHeight: 42
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTabList
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    // the next enabled option in direction d (disabled ones are skipped; stops at either end)
    function step(d: int): void {
        const i = options.findIndex(o => o.id === current);
        for (let j = i < 0 ? (d > 0 ? 0 : options.length - 1) : i + d; j >= 0 && j < options.length; j += d) {
            if (options[j].disabled === true)
                continue;
            if (options[j].id !== current)
                picked(options[j].id);
            return;
        }
    }
    FocusRing {}
    radius: 14
    color: accent ? Theme.alpha(Theme.colors.surface0, 0.55) : Theme.colors.surface1
    border.width: 1
    border.color: Theme.colors.outline

    RowLayout {
        anchors.fill: parent
        anchors.margins: 5          // 1 px border + 4 px padding (mock.css .seg): options are 32 px tall
        spacing: 4
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property bool on: modelData.id === root.current
                readonly property bool off: modelData.disabled === true
                opacity: off ? 0.45 : 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: on ? Theme.colors.surface3 : area.containsMouse && !off ? Theme.colors.surface2 : "transparent"
                border.width: on && root.accent ? 1 : 0
                border.color: Theme.alpha(Theme.colors.accent, 0.45)
                Behavior on color { CAnim {} }
                Rectangle {
                    // box-shadow 0 1px 0 glass-hl: a highlight line under the selected option
                    visible: opt.on
                    x: parent.radius; y: parent.height; width: parent.width - 2 * parent.radius; height: 1
                    color: Theme.colors.glassHighlight
                }
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7
                    Kanji {
                        visible: text !== ""
                        text: opt.modelData.kanji ?? ""
                        size: 15
                        color: opt.on ? Theme.colors.text : Theme.colors.textMuted
                    }
                    OIcon {
                        visible: (opt.modelData.icon ?? "") !== ""
                        icon: opt.modelData.icon ?? ""
                        size: 15
                        color: opt.on ? (root.accent ? Theme.colors.accent : Theme.colors.text) : Theme.colors.textMuted
                    }
                    OText {
                        text: opt.modelData.label
                        size: root.accent ? 13 : 12.5
                        font.weight: root.accent ? Font.DemiBold : Font.Medium
                        tabular: root.accent
                        color: opt.on ? (root.accent ? Theme.colors.accent : Theme.colors.text) : Theme.colors.textMuted
                    }
                    Rectangle {
                        visible: (opt.modelData.chip ?? "") !== ""
                        implicitWidth: chipText.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Theme.colors.surface3
                        OText {
                            id: chipText
                            anchors.centerIn: parent
                            text: opt.modelData.chip ?? ""
                            size: 10
                            font.weight: Font.Medium
                            color: Theme.colors.textMuted
                        }
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: opt.off ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!opt.off) root.picked(opt.modelData.id)
                }
                Accessible.role: Accessible.RadioButton
                Accessible.name: opt.modelData.label
                Accessible.checked: opt.on
            }
        }
    }
}
