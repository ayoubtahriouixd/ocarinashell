pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// 文 One toast (mockup 01 .fumi): 372 px glass card, radius 18, 3 px accent bar on the left, 文 watermark,
// header (app icon · app · time), title 14.5/600, body 13 muted (markup), image, actions (30 px buttons),
// inline reply, remaining-time bar 2 px. Hover pauses the timer; drag right to dismiss; critical never expires.
Item {
    id: root
    required property var notif
    readonly property bool critical: notif.urgency === Notifs.urgencyCritical
    // Quickshell 0.3.2 hands expireTimeout over in milliseconds, as sent (`notify-send -t 4000`), not in seconds
    // (values under 100 are taken as seconds, in case a later Quickshell converts them: never an 8 ms toast)
    readonly property int timeout: notif.expireTimeout > 0
        ? (notif.expireTimeout < 100 ? notif.expireTimeout * 1000 : notif.expireTimeout) : Notifs.timeoutMs
    property real remaining: 1
    readonly property var progressHint: notif.hints?.value
    // a shell notice may carry its seal (`-h string:x-ocarina-kanji:忍`): red hanko in the header and the watermark
    readonly property string seal: /^[\u3400-\u9fff]$/.test(String(notif.hints?.["x-ocarina-kanji"] ?? ""))
        ? notif.hints["x-ocarina-kanji"] : ""
    // 鬼 Oni («覚醒», mockup 08): red inset ring and red glow, a black-on-red hanko with a gold rim
    readonly property bool oni: seal === "鬼"
    // app icon: the one sent, else the .desktop entry's, else an image that is really a theme icon name
    // an "image" that is really a theme icon ("x-office-calendar" or "image://icon/x-office-calendar")
    readonly property string imageIcon: notif.image.startsWith("image://icon/") ? notif.image.slice(13)
        : (notif.image !== "" && notif.image.indexOf("/") < 0 && notif.image.indexOf("://") < 0 ? notif.image : "")
    readonly property bool imageIsIcon: imageIcon !== ""
    readonly property string headerIcon: notif.appIcon !== "" ? notif.appIcon
        : (DesktopEntries.byId(notif.desktopEntry)?.icon ?? imageIcon)
    readonly property double born: Date.now()
    property string ago: "ahora"
    Connections {
        target: Time
        function onMinuteTick() {
            const m = Math.round((Date.now() - root.born) / 60000);
            root.ago = m < 1 ? "ahora" : "hace " + m + " min";
        }
    }
    signal closed

    implicitWidth: 372
    implicitHeight: card.implicitHeight

    // life: a single-shot timer that can pause (hover, typing); the bar is redrawn 4× a second, not every frame
    property double deadline: Date.now() + timeout
    property double pausedLeft: -1
    readonly property bool paused: hover.hovered || reply.activeFocus
    onPausedChanged: {
        if (critical)
            return;
        if (paused) {
            pausedLeft = deadline - Date.now();
            life.stop();
        } else if (pausedLeft >= 0) {
            deadline = Date.now() + pausedLeft;
            pausedLeft = -1;
            life.interval = Math.max(1, deadline - Date.now());
            life.start();
        }
    }
    Timer {
        id: life
        interval: root.timeout
        running: !root.critical
        onTriggered: Notifs.expire(root.notif)
    }
    Timer {
        interval: 250
        repeat: true
        running: !root.critical && !root.paused && Motion.enabled
        onTriggered: root.remaining = Math.max(0, (root.deadline - Date.now()) / root.timeout)
    }

    // swipe to dismiss
    property real dragX: 0
    Behavior on dragX { enabled: !swipe.active; Anim { ms: Motion.base } }
    DragHandler {
        id: swipe
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: root.dragX = Math.max(0, translation.x)
        onActiveChanged: {
            if (!active) {
                if (root.dragX > 120)
                    Notifs.dismiss(root.notif);
                else
                    root.dragX = 0;
            }
        }
    }

    Item {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + 13 + 15
        x: root.dragX
        opacity: 1 - Math.min(0.8, root.dragX / 300)

        // toasts are separate cards with gaps between them: one blur region would blur the gaps too, so they use
        // the near-opaque glass (94 %) that the design reserves for "no blur" (docs/02-DISENO §1)
        Item {
            id: glowRef
            anchors.fill: parent
            readonly property real radius: 18
        }
        SoftShadow {
            visible: root.oni
            target: glowRef
            color: Theme.alpha(Theme.colors.oni, 0.35)
            blur: 64
            steps: 10
            offsetY: 0
        }
        PanelSurface {
            anchors.fill: parent
            radius: 18
            alpha: Theme.glassOpaqueAlpha
        }
        Rectangle {
            visible: root.critical || root.oni
            anchors.fill: parent
            radius: 18
            color: "transparent"
            border.width: 1
            border.color: root.oni ? Theme.alpha(Theme.colors.oni, 0.6) : Theme.colors.accent
        }
        // accent bar: the left 3 px of a rounded rectangle, so it follows the card's corners (no mask shader)
        Item {
            width: 3
            height: parent.height
            clip: true
            Rectangle {
                width: 40
                height: parent.height
                radius: 18
                color: root.oni ? Theme.colors.oni : Theme.colors.accent
            }
        }
        Kanji {
            visible: Settings.data.appearance.kanjiDecor
            anchors.right: parent.right
            anchors.rightMargin: root.seal !== "" ? 26 : 10   // a seal watermark clears the close cross
            y: -6
            text: root.seal || "文"
            size: 64
            color: root.oni ? Theme.colors.oni : Theme.colors.text
            opacity: root.oni ? 0.12 : 0.045
        }

        ColumnLayout {
            id: col
            x: 19
            y: 13
            width: parent.width - 19 - 15
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 6
                    color: root.oni ? Theme.colors.oni : root.seal !== "" ? Theme.colors.accent : Theme.colors.surface3
                    border.width: root.oni ? 1 : 0
                    border.color: Theme.colors.oniGold
                    Kanji {
                        anchors.centerIn: parent
                        visible: root.seal !== ""
                        text: root.seal
                        color: root.oni ? Theme.colors.oniInk : Theme.colors.accentInk
                        size: 12
                    }
                    IconImage {
                        anchors.centerIn: parent
                        visible: root.headerIcon !== "" && root.seal === ""
                        implicitSize: 14
                        source: root.headerIcon.startsWith("/") ? "file://" + root.headerIcon
                            : Quickshell.iconPath(root.headerIcon, true)
                    }
                    OIcon {
                        anchors.centerIn: parent
                        visible: root.headerIcon === "" && root.seal === ""
                        icon: root.critical ? "priority_high" : "notifications"
                        size: 14
                    }
                }
                OText {
                    text: root.notif.appName || "Aplicación"
                    textFormat: Text.PlainText      // any D-Bus client sets it: no markup, no remote images
                    size: 12
                    color: Theme.colors.textMuted
                }
                Item { Layout.fillWidth: true }
                OText {
                    text: root.ago
                    size: 12
                    color: Theme.colors.textDim
                }
                OIcon {
                    icon: "close"
                    size: 16
                    color: Theme.colors.textDim
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8          // 32 px touch target
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismiss(root.notif)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    OText {
                        Layout.fillWidth: true
                        // 発表 presenting: no content on screen (the copy is visible to everybody)
                        text: Displays.mirroring ? "Aviso nuevo" : root.notif.summary
                        size: 14.5
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                    OText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: Displays.mirroring ? "" : Notifs.sanitize(root.notif.body)
                        size: 13
                        color: Theme.colors.textMuted
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        lineHeight: 1.1
                        onLinkActivated: link => {
                            if (/^(https?:|mailto:)/.test(link))
                                Qt.openUrlExternally(link);
                        }
                    }
                }
                Image {
                    visible: root.notif.image !== "" && !root.imageIsIcon
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    source: root.notif.image.startsWith("/") ? "file://" + root.notif.image : root.notif.image
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // progress hint (e.g. -h int:value:60)
            Rectangle {
                visible: root.progressHint !== undefined
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.preferredHeight: 4
                radius: 2
                color: Theme.colors.surface3
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.progressHint ?? 0)) / 100
                    height: 4
                    radius: 2
                    color: Theme.colors.accent
                }
            }

            Flow {
                visible: root.notif.actions.some(a => a.identifier !== "default")
                Layout.fillWidth: true
                Layout.topMargin: 11
                spacing: 6
                Repeater {
                    // "default" is the click on the toast itself, not a button
                    model: root.notif.actions.filter(a => a.identifier !== "default")
                    delegate: OButton {
                        required property var modelData
                        required property int index
                        text: modelData.text
                        primary: root.seal === "" && index === root.notif.actions.filter(a => a.identifier !== "default").length - 1
                        ghost: root.seal !== "" && index > 0       // mockup 06: «Ajustes» is a ghost button
                        onClicked: modelData.invoke()
                    }
                }
            }

            TextInput_ {
                id: reply
                visible: root.notif.hasInlineReply
                Layout.fillWidth: true
                Layout.topMargin: 10
                placeholder: root.notif.inlineReplyPlaceholder || "Responder…"
                onAccepted: {
                    root.notif.sendInlineReply(text);
                    text = "";
                }
            }
        }

        // remaining time: the bottom 2 px of rounded rectangles the size of the card (follows the corners)
        Item {
            visible: !root.critical && Motion.enabled     // without motion it would sit full and still: no bar
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            clip: true
            Rectangle {
                y: -(card.height - 2)
                width: card.width
                height: card.height
                radius: 18
                color: Theme.colors.outline
            }
            Item {
                width: card.width * root.remaining
                height: 2
                clip: true
                Rectangle {
                    y: -(card.height - 2)
                    width: card.width
                    height: card.height
                    radius: 18
                    color: Theme.colors.accent
                    opacity: 0.8
                }
            }
        }

        HoverHandler { id: hover }
        TapHandler {
            acceptedButtons: Qt.LeftButton
            // take me there: the app's default action + its window focused (Notifs.goTo), then close
            onTapped: Notifs.open(root.notif)
        }
    }
}
