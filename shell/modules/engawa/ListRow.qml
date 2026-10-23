import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.engawa
import qs.components

// Row for device / network lists: icon, title, subtitle, trailing text or icon; hover surface2.
Rectangle {
    id: root
    property string icon
    property bool iconFill: false
    property string title
    property string subtitle: ""
    property string trailing: ""
    property string trailingIcon: ""
    property bool reserveTrailing: false   // keep the icon's slot even without icon (values stay aligned in a list)
    // what the trailing action does, for screen readers (the icons used by the Wi-Fi and Bluetooth pages)
    property string trailingLabel: ({ more_horiz: "Más opciones: compartir u olvidar", delete: "Olvidar",
                                      delete_forever: "Confirmar olvidar" })[trailingIcon] ?? "Más acciones"
    property bool active: false
    property bool busy: false
    signal clicked
    signal trailingClicked

    implicitHeight: subtitle !== "" ? 48 : 40
    radius: 12
    color: active ? Theme.colors.accentSoft : area.containsMouse ? Theme.colors.surface2 : "transparent"
    Behavior on color { CAnim {} }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10
        OIcon {
            icon: root.icon
            fill: root.iconFill || root.active
            size: 20
            color: root.active ? Theme.colors.accent : Theme.colors.text
            opacity: root.busy ? 0.5 : 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            OText { Layout.fillWidth: true; text: root.title; size: 13; font.weight: root.active ? Font.DemiBold : Font.Normal }
            OText { Layout.fillWidth: true; visible: root.subtitle !== ""; text: root.subtitle; size: 11.5; color: Theme.colors.textMuted }
        }
        OText {
            visible: root.trailing !== ""
            text: root.trailing
            size: 11.5
            color: Theme.colors.textMuted
            tabular: true
        }
        OIcon {
            visible: root.trailingIcon !== "" || root.reserveTrailing
            opacity: root.trailingIcon !== "" ? 1 : 0
            icon: root.trailingIcon || "more_horiz"
            size: 18
            color: Theme.colors.textMuted
            MouseArea {
                enabled: root.trailingIcon !== ""
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.trailingClicked()
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.rightMargin: root.trailingIcon !== "" ? 36 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Accessible.role: Accessible.Button
    Accessible.name: title + (subtitle ? ", " + subtitle : "")
    Accessible.description: trailingIcon !== "" ? trailingLabel + ": tecla Menú, Supr o flecha derecha" : ""
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    // the trailing action from the keyboard: Menu (or Shift+F10), Delete or →
    Keys.onPressed: e => {
        if (trailingIcon === "")
            return;
        if (e.key === Qt.Key_Menu || e.key === Qt.Key_Delete || e.key === Qt.Key_Right
                || (e.key === Qt.Key_F10 && (e.modifiers & Qt.ShiftModifier))) {
            trailingClicked();
            e.accepted = true;
        }
    }
    FocusRing {}
}
