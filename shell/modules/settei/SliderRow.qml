import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// SRow with a thin slider bound to a numeric settings path. The value is written once per gesture (committed);
// `live` follows the knob for subtitles/previews. `format(v)` gives the text shown at the right (optional).
SRow {
    id: root
    property string key
    property real from: 0
    property real to: 1
    property real stepSize: 0.05
    property real sliderWidth: 220
    property bool showValue: true
    property var format: v => String(v)
    readonly property real live: slider.live
    signal changed(real v)
    HSlider {
        id: slider
        Layout.preferredWidth: root.titleWidth > 0 ? -1 : root.sliderWidth
        Layout.fillWidth: root.titleWidth > 0
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: Number(Settings.get(root.key, root.from))
        label: root.title
        valueText: root.format(live)
        onCommitted: v => {
            if (v !== Number(Settings.get(root.key, root.from))) {
                Settings.set(root.key, v);
                root.changed(v);
            }
        }
    }
    OText {
        visible: root.showValue
        Layout.preferredWidth: 52
        horizontalAlignment: Text.AlignRight
        text: root.format(slider.live)
        size: 13
        font.weight: Font.DemiBold
        tabular: true
    }
}
