import QtQuick
import QtQuick.Layouts
import qs.config

// Engawa tile (mock.css .tile): 62 px, icon square 38 (radius 12), title/subtitle, kanji watermark 42 px at 7 %,
// chevron to a detail page. `on` = soft red gradient, accent icon. Click = toggle, chevron = details.
Rectangle {
    id: root
    property string icon
    property string title
    property string subtitle: ""
    property string watermark: ""
    property bool on: false
    property bool hasDetails: true
    signal toggled
    signal details

    implicitHeight: 62
    radius: Theme.radius.card
    border.width: 1
    border.color: on ? Theme.mix(Theme.colors.outline, Theme.colors.accent, 0.3) : Theme.colors.outline
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.on ? Theme.mix(Theme.colors.surface1, Theme.colors.accent, 0.17) : (area.containsMouse ? Theme.colors.surface2 : Theme.colors.surface1) }
        GradientStop { position: 0.75; color: area.containsMouse ? Theme.colors.surface2 : Theme.colors.surface1 }
    }
    scale: area.pressed ? 0.98 : 1
    Behavior on scale { Anim { ms: Motion.micro } }

    Kanji {
        visible: Settings.data.appearance.kanjiDecor && root.watermark !== ""
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        text: root.watermark
        size: 42
        color: root.on ? Theme.colors.accent : Theme.colors.text
        opacity: root.on ? 0.1 : 0.07
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 12
            color: root.on ? Theme.colors.accentSoft : Theme.colors.surface3
            OIcon {
                anchors.centerIn: parent
                icon: root.icon
                fill: root.on
                size: 20
                color: root.on ? Theme.colors.accent : Theme.colors.textMuted
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            OText {
                Layout.fillWidth: true
                text: root.title
                size: 13
                font.weight: Font.DemiBold
            }
            OText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                size: 11.5
                color: Theme.colors.textMuted
            }
        }
        OIcon {
            visible: root.hasDetails
            icon: "chevron_right"
            size: 18
            color: Theme.colors.textDim
            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor
                onClicked: root.details()
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.rightMargin: root.hasDetails ? 36 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
    Accessible.role: Accessible.CheckBox
    Accessible.name: title + (subtitle ? ", " + subtitle : "")
    Accessible.checkable: true
    Accessible.checked: on
    activeFocusOnTab: true
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()
    Keys.onRightPressed: if (hasDetails) details()
    FocusRing {}
}
