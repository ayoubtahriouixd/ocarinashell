import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One resource line of the Fune status card (mockup 09): label 52 px · 5 px asagi bar · value 96 px, right-aligned.
RowLayout {
    id: root
    property string label
    property real value: 0                // 0–1
    property string text
    spacing: 10
    Layout.fillWidth: true
    Layout.preferredHeight: 17                  // 12 px × line-height 1,4 (mock.css)

    OText {
        Layout.preferredWidth: 52
        text: root.label
        size: Theme.font.meta
        color: Theme.colors.textMuted
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 5
        radius: 3
        color: Theme.colors.surface3
        Rectangle {
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            height: parent.height
            radius: 3
            color: Theme.colors.asagi
            visible: root.value > 0
            Behavior on width { Anim { ms: Motion.base } }
        }
    }
    OText {
        Layout.preferredWidth: 96
        horizontalAlignment: Text.AlignRight
        text: root.text
        size: Theme.font.meta
        tabular: true
        color: Theme.colors.textMuted
    }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: label + ": " + text
}
