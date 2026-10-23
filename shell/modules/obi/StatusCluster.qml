pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.obi

// Power profile badge 省/均/速 · live CPU · RAM · GPU rings · Wi-Fi · Bluetooth · volume · battery ring with % (mockups 01/15 .clu; the badge
// moved to the front at Ayoub's request).
// Click → Engawa · wheel → volume · click on the badge → next profile.
// One visual system: every glyph is 18 px, filled, in an equal 20 px slot; «off» states keep the same glyph and
// dim to textDim (no crossed-out shapes); the hover is a pill (in the «isles» bar, the capsule's own shape).
Rectangle {
    id: root
    readonly property bool isles: Settings.data.bar.style === "isles"
    Layout.preferredHeight: 30
    Layout.preferredWidth: row.implicitWidth + (isles ? 16 : 20)
    Layout.alignment: Qt.AlignVCenter
    radius: isles ? height / 2 : Theme.radius.control
    color: area.containsMouse ? Theme.colors.surface2 : "transparent"
    Behavior on color { CAnim {} }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("engawa", "")
    }
    PullDown {
        panel: "engawa"
    }
    WheelStep {
        onStep: dir => dir > 0 ? Audio.increment("5") : Audio.decrement("5")
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Estado: red, Bluetooth, volumen y batería " + Math.round(Power.percent * 100) + " %"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // power profile 省/均/速 first, left of Wi-Fi (Ayoub, 2026-10-17): away from the bell
        Rectangle {
            readonly property bool hot: Power.profile === "performance"
            Layout.rightMargin: 2
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: root.isles ? 11 : 6
            color: hot ? Theme.colors.accent : Theme.alpha(Theme.colors.text, profArea.containsMouse ? 0.16 : 0.09)
            Behavior on color { CAnim {} }
            Kanji {
                anchors.centerIn: parent
                text: Glossary.profile(Power.profile).kanji
                size: 12
                color: parent.hot ? Theme.colors.accentInk : Theme.colors.text
            }
            MouseArea {
                id: profArea
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Power.cycleProfile()
            }
        }
        // CPU · RAM · GPU in real time, next to the profile (Ayoub, fase 14): 墨 ink meters with the number on top
        // (fase 17; hover → their kanji); click → 見張 Mihari
        Item {
            id: usage
            visible: Usage.wanted
            Layout.rightMargin: 2
            implicitWidth: rings.implicitWidth
            implicitHeight: rings.implicitHeight
            RowLayout {
                id: rings
                spacing: 6
                UsageBar { label: "CPU"; kanji: "脳"; value: Usage.cpu; showKanji: usageArea.containsMouse }
                UsageBar { label: "RAM"; kanji: "記"; value: Usage.ram; showKanji: usageArea.containsMouse }
                UsageBar { label: "GPU"; kanji: "絵"; value: Usage.gpu; visible: Usage.hasGpu; showKanji: usageArea.containsMouse }
            }
            MouseArea {
                id: usageArea
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("mihari", "")
            }
            Accessible.role: Accessible.Button
            Accessible.name: "CPU " + Math.round(Usage.cpu * 100) + " %, memoria " + Math.round(Usage.ram * 100)
                             + " %, GPU " + Math.round(Usage.gpu * 100) + " %"
        }
        BarGlyph {
            visible: Net.available
            glyph: Net.wired ? "lan" : !Net.connected || Net.icon === "wifi_off" ? "wifi" : Net.icon
            on: Net.connected
        }
        BarGlyph {
            visible: Bt.available
            glyph: Bt.connected > 0 ? "bluetooth_connected" : "bluetooth"
            on: Bt.enabled
        }
        BarGlyph {
            visible: Audio.available
            glyph: Audio.muted ? "volume_off" : Audio.icon
            on: !Audio.muted
        }
        RowLayout {
            visible: Power.hasBattery
            spacing: 5
            Layout.leftMargin: 2
            BatteryRing {
                value: Power.percent
                color: Power.low ? Theme.colors.error : Power.charging ? Theme.colors.success : Theme.colors.text
            }
            OText {
                text: Math.round(Power.percent * 100)
                tabular: true
                size: 12
                font.weight: Font.DemiBold
            }
        }
    }
}
