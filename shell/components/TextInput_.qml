import QtQuick
import qs.config
import qs.components

// Single-line text field (password capable) with placeholder. bare: no frame of its own (it sits inside a capsule that
// already draws the focus, like the 器 drawer's search) and the placeholder stays until you type.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool bare: false
    signal accepted
    signal editingFinished               // Enter or focus lost
    readonly property bool editing: input.activeFocus
    implicitHeight: 38
    radius: 10
    color: bare ? "transparent" : Theme.colors.surface2
    border.width: bare ? 0 : input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.colors.accent : Theme.colors.outline
    function focusInput(): void {
        input.forceActiveFocus();
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.bare ? 0 : 12
        anchors.rightMargin: root.bare ? 0 : 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.colors.text
        selectionColor: Theme.colors.accentSoft
        font.family: Theme.font.ui
        font.pointSize: 13 * 0.75
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        activeFocusOnTab: true
        inputMethodHints: root.password ? (Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText) : Qt.ImhNone
        clip: true
        Accessible.role: Accessible.EditableText
        Accessible.name: root.placeholder
        Accessible.passwordEdit: root.password
        onAccepted: root.accepted()
        onEditingFinished: root.editingFinished()
    }
    OText {
        anchors.fill: input
        visible: input.text === "" && (root.bare || !input.activeFocus)
        text: root.placeholder
        color: Theme.colors.textDim
        size: 13
    }
}
