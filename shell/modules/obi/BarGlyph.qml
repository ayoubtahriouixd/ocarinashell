import QtQuick
import qs.config
import qs.components

// One status glyph of the bar: 18 px Material Symbol, filled, optically centred in an equal 20 px slot; «off» dims it.
Item {
    id: slot
    property string glyph
    property bool on: true
    implicitWidth: 20
    implicitHeight: 20
    OIcon {
        anchors.centerIn: parent
        icon: slot.glyph
        fill: true
        optical: true
        size: 18
        color: slot.on ? Theme.colors.text : Theme.colors.textDim
        Behavior on color { CAnim {} }
    }
}
