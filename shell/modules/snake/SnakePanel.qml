pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.components
import qs.services

// 蛇 Snake — the assistant (mockup 11, docs/02-DISENO §5): right 10 · top 56 · 460 wide · up to 760 tall · radius 22.
// Header (snake mark, model · backend · tok/s, «en tu equipo · 0 nube»), the conversation (your bubble, the context
// chips you attached, Snake's answer streamed as it is written, a proposed action as a card with «Ejecutar» /
// «Cancelar»), and the field with ••• (attach context), 声 voice (mic, Ctrl+Space) and send. Nothing runs without
// your click.
PanelSurface {
    id: root
    implicitWidth: 460
    implicitHeight: Math.min(760, (QsWindow.window?.height ?? 1029) - 70)

    property bool attaching: false

    Component.onCompleted: {
        input.forceActiveFocus();
        Snake.refresh();
        Snake.warm();
    }

    function esc(t: string): string {
        return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    // **bold** and `code` of the answers → rich text (escaped first: no markup, no remote image can come through)
    function rich(t: string): string {
        const esc = root.esc(t);
        const code = Theme.colors.surface2.toString();
        return esc.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
                  .replace(/`([^`]+)`/g, "<span style=\"font-family:'" + Theme.font.mono + "'; font-size:12.5px; "
                           + "background-color:" + code + ";\">&nbsp;$1&nbsp;</span>")
                  .replace(/\n/g, "<br>");
    }
    // the answer being written, copied ~16 times a second (not on every token: RichText layout is not free)
    property string streamed: ""
    Timer {
        interval: 60
        repeat: true
        running: Snake.busy || root.streamed !== Snake.streaming
        onTriggered: {
            if (root.streamed === Snake.streaming)
                return;
            const follow = list.atYEnd;
            root.streamed = Snake.streaming;
            if (follow)
                Qt.callLater(() => list.positionViewAtEnd());
        }
    }
    readonly property string subtitle: {
        const n = Snake.name || Snake.model || "sin modelo";
        const b = Snake.backend === "npu" ? "NPU" : "Vulkan";
        if (!Snake.modelPresent)
            return n + " · sin descargar";
        if (Snake.starting)
            return "cargando " + n + "…";
        if (Snake.loaded)
            return n + " · " + b + (Snake.tps > 0 ? " · " + Math.round(Snake.tps) + " tok/s" : "");
        return n + " · " + b + " · parado (0 MB)";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 11
            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 12
                color: Theme.colors.surface2
                // the snake mark (mockup 11): body, head with eye, forked tongue in accent
                Shape {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    scale: 30 / 32
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.colors.text
                        strokeWidth: 2.6
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M4.5 27.5c4.2.4 6.6-1.5 8.4-4.3 1.7-2.7 3.4-4.3 6.8-4.6 3.9-.4 6.6-2.6 6.4-6.2-.2-3.3-3-5.2-6.4-4.9" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.colors.text
                        PathSvg { path: "M19.3 4.6c2.6-.6 4.6.4 4.8 2.2.2 1.7-1.6 3-4.2 3.2-1.4.1-2.7-.4-3.2-1.4-.5-1.4.6-3.5 2.6-4z" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.colors.surface2
                        PathSvg { path: "M19.75 6.6a.85 .85 0 1 0 -1.7 0a.85 .85 0 1 0 1.7 0z" }
                    }
                    ShapePath {
                        strokeColor: Theme.colors.accent
                        strokeWidth: 1.15
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M16.4 8.2 13.6 9m2.8-.8-2.3 2" }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    spacing: 3
                    Kanji { text: "蛇"; size: 13 }
                    OText {
                        text: "Snake · local"
                        size: 15
                        font.weight: Font.DemiBold
                    }
                }
                OText {
                    Layout.fillWidth: true
                    text: root.subtitle
                    size: Theme.font.small
                    color: Theme.colors.textMuted
                }
            }
            Chip {
                text: "en tu equipo · 0 nube"
                tone: "ok"
            }
        }

        // ── conversation ──
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
            clip: true
            spacing: 14
            model: Snake.messages
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(() => list.positionViewAtEnd())

            delegate: Item {
                id: msg
                required property var modelData
                required property int index
                readonly property var act: Snake.actionStates[String(index)] ?? null
                readonly property string st: act?.state ?? ""
                width: ListView.view.width
                implicitHeight: body.implicitHeight

                ColumnLayout {
                    id: body
                    width: parent.width
                    spacing: 14

                    // you
                    Rectangle {
                        visible: msg.modelData.role === "user"
                        Layout.alignment: Qt.AlignRight
                        Layout.maximumWidth: msg.width * 0.8
                        implicitWidth: Math.min(msg.width * 0.8, userText.implicitWidth + 28)
                        implicitHeight: userText.implicitHeight + 20
                        radius: 16
                        color: Theme.colors.surface2
                        Rectangle {                          // border-radius 16 16 4 16: the corner by the edge
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 16
                            height: 16
                            radius: 4
                            color: parent.color
                        }
                        OText {
                            id: userText
                            x: 14
                            y: 10
                            width: Math.min(implicitWidth, msg.width * 0.8 - 28)
                            text: msg.modelData.text
                            textFormat: Text.PlainText
                            size: 13.5
                            wrapMode: Text.Wrap
                            maximumLineCount: 40
                        }
                    }
                    Flow {
                        visible: msg.modelData.role === "user" && (msg.modelData.attach ?? []).length > 0
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: msg.modelData.attach ?? []
                            delegate: Chip {
                                required property string modelData
                                readonly property var kind: Snake.attachKinds.find(k => k.id === modelData) ?? {}
                                text: kind.label ?? modelData
                                icon: kind.icon ?? ""
                                kanji: kind.kanji ?? ""
                            }
                        }
                    }
                    // Snake
                    Text {
                        visible: msg.modelData.role === "assistant"
                        Layout.fillWidth: true
                        text: root.rich(msg.modelData.text ?? "")
                        textFormat: Text.RichText
                        wrapMode: Text.Wrap
                        color: Theme.colors.text
                        font.family: Theme.font.ui
                        font.pointSize: 13.5 * 0.75 * Theme.font.scale
                        lineHeight: 1.18
                    }
                    Chip {
                        visible: msg.modelData.role === "assistant" && (msg.modelData.suspicious ?? false)
                        text: "contenido sospechoso en los datos: ignorado"
                        tone: "red"
                        icon: "gpp_maybe"
                    }
                    // the proposed action
                    Rectangle {
                        visible: msg.modelData.role === "assistant" && msg.modelData.action !== null
                        Layout.fillWidth: true
                        implicitHeight: card.implicitHeight + 24
                        radius: Theme.radius.card
                        color: Theme.colors.surface1
                        border.width: 1
                        border.color: Theme.colors.outline
                        opacity: msg.st === "cancelled" ? 0.5 : 1
                        ColumnLayout {
                            id: card
                            x: 14
                            y: 12
                            width: parent.width - 28
                            spacing: 0
                            RowLayout {
                                spacing: 8
                                OIcon { icon: "bolt"; size: 18 }
                                OText {
                                    text: "Acción propuesta"
                                    size: 13
                                    font.weight: Font.DemiBold
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 10
                                implicitHeight: cmd.implicitHeight + 16
                                radius: 9
                                color: Theme.colors.surface0
                                border.width: 1
                                border.color: Theme.colors.outline
                                Text {
                                    id: cmd
                                    x: 10
                                    y: 8
                                    width: parent.width - 20
                                    textFormat: Text.StyledText
                                    text: "<font color=\"" + Theme.colors.accent + "\">❯</font> "
                                          + root.esc((msg.modelData.action?.argv ?? []).join(" "))
                                    color: Theme.colors.text
                                    font.family: Theme.font.mono
                                    font.pointSize: 12.5 * 0.75 * Theme.font.scale
                                    elide: Text.ElideRight
                                }
                            }
                            OText {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                // what it does (actions.json) — the model's reason only when there is none
                                text: msg.modelData.action?.detail || (msg.modelData.action?.reason ?? "")
                                textFormat: Text.PlainText      // the reason is the model's: no markup
                                size: 12
                                color: Theme.colors.textMuted
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                            }
                            RowLayout {
                                Layout.topMargin: 10
                                spacing: 6
                                visible: msg.st === ""
                                OButton {
                                    text: "Ejecutar"
                                    icon: "check"
                                    primary: true
                                    onClicked: Snake.runAction(msg.index)
                                }
                                OButton {
                                    text: "Cancelar"
                                    onClicked: Snake.dismissAction(msg.index)
                                }
                            }
                            OText {
                                Layout.topMargin: 10
                                visible: msg.st !== ""
                                text: msg.st === "running" ? "Ejecutando…"
                                    : msg.st === "done" ? "Hecho ✓"
                                    : msg.st === "failed" ? "La acción falló (journalctl -t ocarina-snake)"
                                    : "Cancelada"
                                size: 12
                                color: msg.st === "failed" ? Theme.colors.error : Theme.colors.textMuted
                            }
                            // what the command said (doctor, smoke, update --check are reports)
                            Text {
                                visible: (msg.act?.output ?? "") !== ""
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                text: msg.act?.output ?? ""
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 8
                                elide: Text.ElideRight
                                color: Theme.colors.textMuted
                                font.family: Theme.font.mono
                                font.pointSize: 11 * 0.75 * Theme.font.scale
                            }
                        }
                    }
                    // notes (policy, errors)
                    OText {
                        visible: msg.modelData.role === "note"
                        Layout.fillWidth: true
                        text: msg.modelData.text
                        textFormat: Text.PlainText
                        size: 12
                        color: Theme.colors.textDim
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                    }
                }
            }

            footer: Item {
                width: ListView.view.width
                implicitHeight: foot.implicitHeight + 14
                ColumnLayout {
                    id: foot
                    y: 14
                    width: parent.width
                    spacing: 10
                    Text {                               // the answer while it is being written
                        visible: root.streamed !== ""
                        Layout.fillWidth: true
                        text: root.rich(root.streamed) + "<font color=\"" + Theme.colors.accent + "\"> ▍</font>"
                        textFormat: Text.RichText
                        wrapMode: Text.Wrap
                        color: Theme.colors.text
                        font.family: Theme.font.ui
                        font.pointSize: 13.5 * 0.75 * Theme.font.scale
                        lineHeight: 1.18
                    }
                    OText {
                        visible: Snake.busy && root.streamed === ""
                        text: Snake.starting ? "Cargando el modelo en la GPU…" : "Pensando…"
                        size: 12
                        color: Theme.colors.textMuted
                    }
                    OText {
                        visible: Snake.messages.length > 0
                        text: "Snake propone; nada se ejecuta sin tu confirmación."
                        size: 12
                        color: Theme.colors.textDim
                    }
                }
            }

            // empty: what it is and what it costs
            ColumnLayout {
                visible: Snake.messages.length === 0 && !Snake.busy
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 8
                Kanji {
                    Layout.alignment: Qt.AlignHCenter
                    text: "蛇"
                    size: 44
                    color: Theme.colors.textDim
                }
                OText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Pregunta lo que quieras: todo se queda en tu equipo."
                    wrapMode: Text.Wrap
                    color: Theme.colors.textMuted
                }
                OText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: !Snake.canLoad && !Snake.loaded ? Snake.policy
                        : Snake.loaded ? "Cargado: responde al momento."
                        : Snake.starting ? "Cargando en la GPU (unos segundos): puedes ir escribiendo."
                        : "Parado (0 MB). Se carga al preguntar y se descarga a los "
                          + (Settings.data.snake.keepAliveMin ?? 5) + " min sin uso."
                    size: 12
                    wrapMode: Text.Wrap
                    color: Theme.colors.textDim
                }
            }
        }

        // ── context to attach (•••) ──
        Flow {
            visible: root.attaching
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 6
            Repeater {
                model: Snake.attachKinds
                delegate: Chip {
                    id: chip
                    required property var modelData
                    readonly property bool on: Snake.attach.indexOf(modelData.id) >= 0
                    text: modelData.label
                    icon: modelData.icon ?? ""
                    kanji: modelData.kanji ?? ""
                    tone: on ? "red" : ""
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4                // a 32 px target on a 24 px chip
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Snake.toggleAttach(chip.modelData.id)
                    }
                    activeFocusOnTab: true
                    Keys.onReturnPressed: Snake.toggleAttach(modelData.id)
                    Keys.onSpacePressed: Snake.toggleAttach(modelData.id)
                    FocusRing {}
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: "Adjuntar " + modelData.label
                    Accessible.checkable: true
                    Accessible.checked: on
                    Accessible.onToggleAction: Snake.toggleAttach(modelData.id)
                }
            }
        }

        // ── the field ──
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            implicitHeight: 44
            radius: 14
            color: Theme.colors.surface1
            border.width: 1
            border.color: input.activeFocus ? Theme.alpha(Theme.colors.accent, 0.5) : Theme.colors.outline
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                spacing: 10
                Kanji { text: "蛇"; size: 16 }
                TextInput {
                    id: input
                    Layout.fillWidth: true
                    color: Theme.colors.text
                    font.family: Theme.font.ui
                    font.pointSize: Theme.font.body * 0.75 * Theme.font.scale
                    selectionColor: Theme.alpha(Theme.colors.accent, 0.35)
                    clip: true
                    onAccepted: {
                        if (Snake.ask(text))
                            text = "";
                    }
                    OText {
                        visible: input.text === ""
                        width: input.width
                        elide: Text.ElideRight
                        text: Snake.listening ? "Te escucho… (una pausa y pregunto)" : Snake.transcribing ? "Transcribiendo…"
                            : Snake.busy ? "Snake está respondiendo…" : "Pregunta a Snake…  ·  Ctrl+Espacio: voz"
                        color: Snake.listening ? Theme.colors.accent : Theme.colors.textDim
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Space && (e.modifiers & Qt.ControlModifier)) {
                            Snake.listen();
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Escape && Snake.voiceBusy) {
                            Snake.cancelListen();
                            e.accepted = true;
                        }
                    }
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Pregunta a Snake"
                }
                // ••• attach context
                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    // the dots breathe while Snake writes (docs/02-DISENO §Snake); static otherwise
                    Item {
                        id: pulse
                        anchors.fill: parent
                    }
                    SequentialAnimation {
                        running: Snake.busy && Motion.enabled
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) pulse.opacity = 1
                        OpacityAnimator { target: pulse; from: 1; to: 0.35; duration: Motion.d(Motion.base) * 3 }
                        OpacityAnimator { target: pulse; from: 0.35; to: 1; duration: Motion.d(Motion.base) * 3 }
                    }
                    Row {
                        parent: pulse
                        anchors.centerIn: parent
                        spacing: 4
                        opacity: root.attaching || Snake.attach.length > 0 || Snake.busy ? 1 : 0.5
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                width: 5
                                height: 5
                                radius: 3
                                color: Snake.attach.length > 0 ? Theme.colors.accent : Theme.colors.text
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.attaching = !root.attaching
                    }
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.attaching = !root.attaching
                    Keys.onSpacePressed: root.attaching = !root.attaching
                    FocusRing {}
                    Accessible.role: Accessible.Button
                    Accessible.name: "Adjuntar contexto"
                    Accessible.onPressAction: root.attaching = !root.attaching
                }
                // 声 voice: the halo follows the microphone level (a meter, not an ornament: it moves with the voice
                // even with reduced motion, but without easing)
                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32 + 14 * Snake.level
                        height: width
                        radius: width / 2
                        visible: Snake.listening
                        color: Theme.alpha(Theme.colors.accent, 0.18 + 0.3 * Snake.level)
                    }
                    IconButton {
                        anchors.fill: parent
                        enabled: !Snake.busy
                        icon: Snake.transcribing ? "hourglass_top" : Snake.listening ? "stop_circle" : "mic"
                        label: Snake.listening ? "Parar y preguntar" : Snake.transcribing ? "Transcribiendo" : "Preguntar por voz (Ctrl+Espacio)"
                        onClicked: Snake.listen()
                    }
                }
                IconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: Snake.busy ? "stop" : "arrow_upward"
                    label: Snake.busy ? "Parar" : "Enviar"
                    onClicked: {
                        if (Snake.busy) {
                            Snake.cancel();
                        } else if (Snake.ask(input.text)) {
                            input.text = "";
                        }
                    }
                }
            }
        }
    }
}
