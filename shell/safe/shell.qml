//@ pragma ShellId ocarina-safe
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io

// 殻 Modo seguro (docs/06-ACTUALIZACIONES capa 4). Started by ocarinashell-safe.service when the normal shell
// fails repeatedly (OnFailure=). Deliberately primitive: only PanelWindow, Rectangle, Text, MouseArea, Timer,
// Process and FileView — no singletons, no services, no optional modules — so that an update that breaks the
// normal shell cannot break this one. Colours are literal on purpose (Theme may be what is broken).
ShellRoot {
    id: safe

    property string clock: Qt.formatTime(new Date(), "HH:mm")
    property string battery: ""

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            safe.clock = Qt.formatTime(new Date(), "HH:mm");
            bat.reload();
        }
    }
    FileView {
        id: bat
        path: "/sys/class/power_supply/BAT0/capacity"
        printErrors: false
        onLoaded: safe.battery = text().trim()
    }

    // The normal shell died while the screen was locked (Kagi leaves a flag in $XDG_RUNTIME_DIR): swaylock takes the
    // lock at once and the flag goes away only after a successful unlock (swaylock without -f blocks until then).
    Process {
        running: true
        command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/ocarinashell/locked"; [ -e "$f" ] || exit 0; '
                 + 'swaylock -c 0b0a0c && rm -f "$f"']
    }

    // `var`, not list<string>: an array that comes from a Repeater's modelData reaches a list<string> parameter EMPTY
    // (Qt 6.12, verified) — every button here did nothing until simulacro d of fase 14 caught it
    function exec(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    // 診 Diagnosis on screen: the errors of the normal shell's last runs in this boot (QML load errors name the file,
    // line and missing module), the first «caused by» as the one-line cause in the bar, and when safe mode began.
    property string cause: ""
    property string diagText: ""
    property bool diagOpen: false
    property string since: Qt.formatTime(new Date(), "HH:mm")
    Process {
        id: diag
        running: true
        command: ["sh", "-c", "journalctl --user -u ocarinashell -b -n 600 -o cat --no-pager 2>/dev/null"
                 + " | sed 's/\\x1b\\[[0-9;]*m//g'"
                 + " | grep -E 'ERROR|caused by|TypeError|ReferenceError|is not installed|unavailable|Failed to load'"
                 + " | grep -v 'Could not register app ID' | tail -n 14"]
        stdout: StdioCollector {
            onStreamFinished: {
                safe.diagText = text.trim() !== "" ? text.trim() : "El journal no tiene errores de la shell en este arranque.";
                const lines = text.split("\n").map(l => l.trim()).filter(l => l !== "");
                const c = lines.filter(l => l.indexOf("caused by") >= 0);
                safe.cause = (c.length > 0 ? c[c.length - 1] : (lines[lines.length - 1] ?? ""))
                    .replace(/^.*caused by\s*/, "").replace(/^\s*ERROR:?\s*/, "").slice(0, 110);
            }
        }
    }

    Variants {
        model: safe.diagOpen ? Quickshell.screens : []
        delegate: PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; right: true }
            margins { top: 8; right: 10 }
            implicitWidth: Math.min(980, modelData.width - 20)
            implicitHeight: body.implicitHeight + 28
            exclusiveZone: 0
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "#f50f0d11"
                border.width: 1
                border.color: "#5a2a33"
                Column {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 8
                    Text {
                        text: "診 Diagnóstico · modo seguro desde las " + safe.since
                        color: "#f4efe6"
                        font.family: "Geist"
                        font.pointSize: 10.5
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WrapAnywhere
                        text: safe.diagText
                        color: "#e9dfd3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pointSize: 8.5
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Reintentar vuelve a la shell normal. Si cae otra vez: «ocarina doctor» en la terminal, "
                              + "o «cd ~/ocarinashell && git log --oneline -5» y revierte el último cambio (docs/05-RESCATE.md)."
                        color: "#a89f96"
                        font.family: "Geist"
                        font.pointSize: 9
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            margins { top: 8; left: 10; right: 10 }
            implicitHeight: 40
            exclusiveZone: 40
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "#f0141216"
                border.width: 1
                border.color: "#e60033"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 7
                        color: "#e60033"
                        Text {
                            anchors.centerIn: parent
                            text: "殻"
                            color: "#ffffff"
                            font.family: "Shippori Mincho B1"
                            font.pointSize: 11
                            font.bold: true
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Modo seguro · la shell normal no arrancó" + (safe.cause !== "" ? " · " : ". Mamori intentará repararla.")
                        color: "#f4efe6"
                        font.family: "Geist"
                        font.pointSize: 10
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: safe.cause !== ""
                        width: Math.min(implicitWidth, bar.width * 0.34)
                        elide: Text.ElideRight
                        text: safe.cause
                        color: "#ff8fa3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pointSize: 9
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "Diagnóstico", cmd: [] },
                            { label: "Reintentar", cmd: ["sh", "-c", "systemctl --user reset-failed ocarinashell; systemctl --user start ocarinashell"] },
                            { label: "Terminal", cmd: ["sh", "-c", "ghostty +new-window || alacritty"] },
                            { label: "Ver errores", cmd: ["sh", "-c", "ghostty -e sh -c 'journalctl --user -u ocarinashell -b -n 300 --no-pager | less +G' || alacritty -e journalctl --user -u ocarinashell -b -n 300"] },
                            { label: "Bloquear", cmd: ["swaylock", "-f"] }
                        ]
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            width: label.implicitWidth + 22
                            height: 28
                            radius: 9
                            color: ma.containsMouse ? "#2e2830" : "#241f26"
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: btn.modelData.label
                                color: "#f4efe6"
                                font.family: "Geist"
                                font.pointSize: 9.5
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (btn.modelData.cmd.length === 0) {
                                        safe.diagOpen = !safe.diagOpen;
                                        diag.running = true;          // fresh lines every time it opens
                                    } else {
                                        safe.exec(btn.modelData.cmd);
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 8
                        text: (safe.battery !== "" ? safe.battery + " %  ·  " : "") + safe.clock
                        color: "#f4efe6"
                        font.family: "Geist"
                        font.pointSize: 10.5
                        font.bold: true
                    }
                }
            }
        }
    }
}
