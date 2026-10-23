import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.engawa
import qs.components

// Detail page header: back chevron, title with its kanji, optional switch on the right.
RowLayout {
    id: root
    property string title
    property string kanji: ""
    property bool hasSwitch: false
    property bool checked: false
    property bool showBack: true          // false when the page is embedded in Settei
    signal back
    signal toggled
    spacing: 10

    IconButton {
        visible: root.showBack
        icon: "chevron_left"
        label: "Atrás"
        onClicked: root.back()
    }
    Kanji {
        visible: root.kanji !== ""
        text: root.kanji
        size: 20
        color: Theme.colors.accent
    }
    OText {
        Layout.fillWidth: true
        text: root.title
        size: 15
        font.weight: Font.DemiBold
    }
    Switch_ {
        visible: root.hasSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
