import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// 1 × 18 px divider (mock.css .obi .sep), snapped to whole physical pixels so every separator looks the same.
Rectangle {
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1.75
    Layout.preferredWidth: Math.max(1, Math.round(dpr)) / dpr
    Layout.preferredHeight: 18
    Layout.alignment: Qt.AlignVCenter
    color: Theme.colors.outlineStrong
}
