pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.config
import qs.components
import qs.services
import qs.modules.kagi

// 認 Polkit dialog: glass card over a scrim, icon of the action, its message, who authenticates (when there is a
// choice), password with petals, foldable details, Cancelar / Autenticar. Esc cancels. Exclusive keyboard.
PanelWindow {
    id: win

    required property AuthFlow flow

    WlrLayershell.namespace: "ocarina-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.alpha("#040305", 0.78)

    property bool details: false
    property int tries: 0
    property bool lastFailed: false
    property bool busy: false

    // polkit ships no Spanish catalogue here: the usual actions are said in Spanish, the original goes to Detalles
    function spanish(action: string, msg: string): string {
        if (action === "org.freedesktop.policykit.exec") {
            const m = /run [`'"](.+?)['"`] as/.exec(msg);
            return m ? "Ejecutar «" + m[1] + "» como administrador" : "Ejecutar un programa como administrador";
        }
        const known = {
            "org.freedesktop.systemd1.manage-units": "Gestionar servicios del sistema",
            "org.freedesktop.systemd1.manage-unit-files": "Activar o desactivar servicios del sistema",
            "org.freedesktop.NetworkManager.settings.modify.system": "Cambiar la configuración de red del sistema",
            "org.freedesktop.NetworkManager.network-control": "Controlar la red",
            "org.freedesktop.login1.reboot-multiple-sessions": "Reiniciar con otras sesiones abiertas",
            "org.freedesktop.login1.power-off-multiple-sessions": "Apagar con otras sesiones abiertas",
            "org.freedesktop.udisks2.filesystem-mount-system": "Montar un disco del sistema",
            "org.freedesktop.udisks2.encrypted-unlock-system": "Desbloquear un disco cifrado",
            "org.freedesktop.timedate1.set-timezone": "Cambiar la zona horaria",
            "org.freedesktop.locale1.set-locale": "Cambiar el idioma del sistema",
            "org.freedesktop.packagekit.package-install": "Instalar software",
            "org.freedesktop.fwupd.update-internal": "Actualizar el firmware"
        };
        return known[action] ?? msg;
    }

    function submit(secret: string): void {
        if (!flow || !flow.isResponseRequired || busy)
            return;
        busy = true;
        flow.submit(secret);
        field.clear();
    }

    Connections {
        target: win.flow
        function onAuthenticationFailed() {
            win.busy = false;
            win.tries++;
            win.lastFailed = true;
            field.shake();
        }
        function onIsResponseRequiredChanged() {
            if (win.flow.isResponseRequired) {
                win.busy = false;
                field.focusInput();
            }
        }
        function onAuthenticationSucceeded() {
            win.busy = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: field.focusInput()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 452
        height: col.implicitHeight + 48
        radius: Theme.radius.panel
        color: Theme.alpha(Theme.colors.surface0, Theme.glassOpaqueAlpha)
        border.width: 1
        border.color: Theme.colors.glassBorder
        opacity: 0
        transform: Translate { id: enterY; y: 8 }
        Component.onCompleted: enter.start()

        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            spacing: 14

            Row {
                spacing: 14
                Rectangle {
                    width: 46
                    height: 46
                    radius: 12
                    color: Theme.colors.accentSoft
                    Image {
                        id: actionIcon
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        sourceSize: Qt.size(56, 56)
                        source: (win.flow?.iconName ?? "") !== "" ? Quickshell.iconPath(win.flow.iconName, true) : ""
                        visible: status === Image.Ready
                    }
                    OIcon {
                        anchors.centerIn: parent
                        visible: !actionIcon.visible
                        icon: "admin_panel_settings"
                        fill: true
                        size: 24
                        color: Theme.colors.accent
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: col.width - 46 - 14
                    spacing: 4
                    Row {
                        spacing: 8
                        Kanji { text: "認"; size: 18; color: Theme.colors.textMuted }
                        OText { text: "Autenticación requerida"; size: Theme.font.h3; font.weight: Font.DemiBold }
                    }
                    OText {
                        width: parent.width
                        text: "Una aplicación pide permisos de administrador"
                        size: Theme.font.small
                        color: Theme.colors.textMuted
                    }
                }
            }

            OText {
                width: parent.width
                text: win.spanish(win.flow?.actionId ?? "", win.flow?.message ?? "")
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                size: Theme.font.body
            }

            // identity: only when there is more than one (e.g. several admin users)
            Flow {
                width: parent.width
                spacing: 6
                visible: (win.flow?.identities?.length ?? 0) > 1
                Repeater {
                    model: win.flow?.identities ?? []
                    delegate: Rectangle {
                        id: who
                        required property var modelData
                        readonly property bool chosen: win.flow.selectedIdentity === modelData
                        width: whoText.implicitWidth + 22
                        height: 32
                        radius: Theme.radius.chip
                        color: chosen ? Theme.colors.accentSoft : Theme.colors.surface2
                        border.width: 1
                        border.color: chosen ? Theme.colors.accent : Theme.colors.outline
                        OText {
                            id: whoText
                            anchors.centerIn: parent
                            text: who.modelData.displayName ?? String(who.modelData)
                            size: Theme.font.small
                            color: who.chosen ? Theme.colors.accent : Theme.colors.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.flow.selectedIdentity = who.modelData
                        }
                    }
                }
            }

            OText {
                // PAM prompts arrive in the system language or in English: «Password:» → «Contraseña»
                text: {
                    const p = (win.flow?.inputPrompt ?? "").replace(/:\s*$/, "").trim();
                    return p === "" || /password|contrase/i.test(p) ? "Contraseña" : p;
                }
                size: Theme.font.small
                color: Theme.colors.textMuted
            }
            PasswordField {
                id: field
                width: parent.width
                interactive: win.flow?.isResponseRequired ?? false
                busy: win.busy
                error: win.lastFailed
                Component.onCompleted: focusInput()
                onSubmitted: secret => win.submit(secret)
                Keys.onEscapePressed: win.flow.cancelAuthenticationRequest()
            }
            OText {
                width: parent.width
                visible: text !== ""
                text: win.lastFailed && !(win.flow?.supplementaryIsError ?? false) ? "Contraseña incorrecta"
                    : (win.flow?.supplementaryMessage ?? "")
                color: win.lastFailed || (win.flow?.supplementaryIsError ?? false) ? Theme.colors.error : Theme.colors.textMuted
                size: Theme.font.small
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }

            // details
            Item {
                width: parent.width
                height: 22
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    OIcon {
                        icon: "chevron_right"
                        size: 16
                        color: Theme.colors.textMuted
                        rotation: win.details ? 90 : 0
                        Behavior on rotation { Anim { ms: Motion.fast } }
                    }
                    OText { text: "Detalles"; size: Theme.font.small; color: Theme.colors.textMuted }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.details = !win.details
                }
            }
            OText {
                visible: win.details
                width: parent.width
                text: "Acción: " + (win.flow?.actionId ?? "") + "\n" + (win.flow?.message ?? "")
                font.family: Theme.font.mono
                size: Theme.font.caption
                color: Theme.colors.textMuted
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
            }

            Row {
                anchors.right: parent.right
                spacing: 10
                OButton {
                    text: "Cancelar"
                    onClicked: win.flow.cancelAuthenticationRequest()
                }
                OButton {
                    text: "Autenticar"
                    primary: true
                    enabled: field.text !== "" && !win.busy
                    opacity: enabled ? 1 : 0.4
                    onClicked: win.submit(field.text)
                }
            }
        }
    }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
        NumberAnimation { target: enterY; property: "y"; to: 0; duration: Motion.d(Motion.base); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decel }
    }
}
