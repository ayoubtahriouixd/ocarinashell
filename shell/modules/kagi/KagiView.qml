pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.kagi

// 鍵 Kagi — the lock screen composition (mockup 03, docs/02-DISENO §5). Shared by the real lock (WlSessionLockSurface),
// test mode (Overlay layer) and the dissolve ghost; the greeter (phase 13) reuses it.
// Asymmetric: left column (mark + greeting · kanji date · clock 196/200 · Spanish date, weather, 七十二候 · petals field ·
// hints), right the proverb of the day in 縦書き with its hanko; mini player bottom-left; Wi-Fi and battery top-right.
// Secondary screens show only the clock. Background: pre-blurred wallpaper + vignette (no live blur).
Item {
    id: root

    property bool primary: true
    property bool interactive: true
    property bool ghost: false            // the dissolving copy: static logo, no input
    // idle animations allowed: lock visible, screen on, not 忍 Shinobi
    readonly property bool live: !Lock.screenOff && Motion.enabled && !Modes.shinobi
    signal dissolved()

    function focusInput(): void {
        field.focusInput();
    }
    // success: the ocarina bursts (on the lock surface); the overlay copy then fades whole (300 ms) into the desktop
    function burst(): void {
        logo.burst();
    }
    function dissolve(): void {
        fadeOut.restart();
    }

    // ------------------------------------------------------------------ background
    Rectangle {
        anchors.fill: parent
        color: Theme.colors.bg
    }
    Image {
        anchors.fill: parent
        anchors.margins: -40          // mockup: inset -40px, so the soft edge never shows
        // lock.blurWallpaper (Settei → Bloqueo): pre-blurred copy, or the wallpaper as it is
        source: Settings.data.lock.blurWallpaper ? (Lock.backdrop !== "" ? Paths.url(Lock.backdrop) : "")
            : (Lock.wallpaperPath !== "" ? Paths.url(Lock.wallpaperPath) : "")
        // the original may be an 8K download: decode it at the screen's size, never full
        sourceSize.width: Settings.data.lock.blurWallpaper ? 0 : Math.ceil((width || 1646) * 2)   // ≥ dpr 1.75; 0 = natural size
        fillMode: Image.PreserveAspectCrop
        asynchronous: false           // already decoded by the time the lock maps (shared pixmap cache)
        cache: true
        smooth: true
    }
    // brightness(.62) of the mockup
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.38
    }
    // vignette: radial-gradient(ellipse at 30% 50%, transparent 30%, rgba(0,0,0,.55) 100%)
    Shape {
        id: vignette
        readonly property real rx: root.width * 0.7 * Math.SQRT2
        readonly property real ry: root.height * 0.5 * Math.SQRT2
        x: root.width * 0.3 - rx
        y: root.height * 0.5 - rx
        width: 2 * rx
        height: 2 * rx
        transform: Scale { origin.x: vignette.rx; origin.y: vignette.rx; yScale: vignette.ry / vignette.rx }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: vignette.rx; centerY: vignette.rx; centerRadius: vignette.rx
                focalX: vignette.rx; focalY: vignette.rx
                GradientStop { position: 0.3; color: "#00000000" }
                GradientStop { position: 1.0; color: "#8c000000" }
            }
            PathRectangle { x: 0; y: 0; width: vignette.width; height: vignette.height }
        }
    }

    // ------------------------------------------------------------------ composition (drifts for 保護 Hogo)
    Item {
        id: comp
        width: root.width
        height: root.height
        // 保護 Hogo: ±6 px, one step a minute with the clock (Lock.driftStep, shared so the ghost does not jump)
        readonly property var steps: [[0, 0], [4, -3], [6, 2], [1, 5], [-4, 3], [-6, -2], [-2, -6], [3, -5]]
        readonly property var offset: Settings.data.oled.lockDrift ? steps[Lock.driftStep % steps.length] : [0, 0]
        transform: Translate { x: comp.offset[0]; y: comp.offset[1] }

        // ---------------------------------------------------------- top-right: Wi-Fi + battery
        Row {
            anchors { right: parent.right; rightMargin: 30; top: parent.top; topMargin: 22 }
            spacing: 14
            visible: root.primary
            OIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Net.icon
                fill: true
                size: 18
                visible: Net.icon !== ""
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: Power.hasBattery
                BatteryRing {
                    anchors.verticalCenter: parent.verticalCenter
                    value: Power.percent
                    color: Power.low ? Theme.colors.error : Theme.colors.text
                }
                OText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Power.percent * 100) + " %" + (Power.charging ? " ·" : "")
                    size: 13
                    tabular: true
                    font.weight: Font.DemiBold
                }
                OIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Power.charging
                    icon: "bolt"
                    fill: true
                    size: 15
                }
            }
        }

        // ---------------------------------------------------------- left column
        Row {
            x: 104
            y: 150
            spacing: 14
            visible: root.primary
            OcarinaLogo {
                id: logo
                anchors.verticalCenter: parent.verticalCenter
                variant: "mark"
                // 忍 Shinobi: the mono mark in muted grey, like the bar (mockup 06)
                style: Modes.shinobi ? "mono" : "gloss"
                monoColor: Theme.colors.textMuted
                monoHoleColor: Theme.oledBlack
                width: 52
                height: Math.round(52 * 270 / 430)
                animated: Motion.enabled && !root.ghost       // the ghost shows the final pose (no intro replay)
                loops: root.live
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (Glossary.g.greetings?.welcomeBack?.jp ?? "お帰りなさい") + "、" + Lock.userName
                color: Theme.colors.text
                font.family: Theme.font.jp
                font.weight: Font.Medium
                font.pointSize: 22 * 0.75 * Theme.font.scale
            }
        }

        Text {
            id: kanjiDate
            x: 106
            y: 257                         // Qt sets the line box ~5 px lower than CSS
            visible: root.primary
            text: {
                const d = Time.now;
                const y = String(d.getFullYear()).split("").map(c => Glossary.numeral(parseInt(c))).join("");
                return y + "年 " + Glossary.number(d.getMonth() + 1) + "月" + Glossary.number(d.getDate()) + "日 "
                     + Glossary.weekday(d.getDay()).kanji + "曜日";
            }
            color: Theme.mix(Theme.colors.text, Theme.colors.textMuted, 0.3)
            font.family: Theme.font.display
            font.weight: Font.Medium
            font.pointSize: 22 * 0.75 * Theme.font.scale
            font.letterSpacing: 22 * 0.18
            renderType: Text.CurveRendering
        }

        Text {
            id: clock
            x: root.primary ? 92 : (root.width - width) / 2
            // 269: Qt places the 196-px line box 31 px lower than CSS line-height:1 (measured against mockup 03)
            y: root.primary ? 269 : (root.height - height) / 2 - 30
            text: Qt.formatTime(Time.now, Time.h24 ? "HH:mm" : "h:mm")   // never seconds on the lock clock
            color: Theme.colors.text
            font.family: Theme.font.ui
            font.weight: Font.ExtraLight
            font.pointSize: 196 * 0.75
            font.letterSpacing: -196 * 0.03
            // no tnum: Geist's tabular 1 grows a foot and a wide colon; the mockup's 21:38 is proportional
            renderType: Text.CurveRendering
            lineHeightMode: Text.FixedHeight
            lineHeight: 196
        }
        OText {
            visible: !root.primary
            anchors.horizontalCenter: clock.horizontalCenter
            anchors.top: clock.bottom
            anchors.topMargin: 18
            text: root.longDate
            size: 16
            color: Theme.colors.textMuted
        }
        OText {
            visible: !root.primary && Lock.message !== ""
            anchors.horizontalCenter: field.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: 14
            text: Lock.message
            size: Theme.font.small
            color: Theme.colors.error
        }

        Row {
            x: 106
            y: 497
            spacing: 12
            visible: root.primary
            OText {
                text: root.longDate
                size: 16
                color: Theme.mix(Theme.colors.text, Theme.colors.textMuted, 0.45)
            }
            OText { text: "·"; size: 16; color: Theme.colors.textDim; visible: Weather.available }
            Kanji {
                visible: Weather.available
                text: Weather.info(Weather.code).kanji
                size: 16
                font.weight: Font.Medium
            }
            OText {
                visible: Weather.available
                text: Math.round(Weather.temperature) + "° " + Settings.data.weather.place
                size: 16
                tabular: true
                color: Theme.mix(Theme.colors.text, Theme.colors.textMuted, 0.45)
            }
            OText { text: "·"; size: 16; color: Theme.colors.textDim; visible: Kisetsu.ko.kanji !== "" }
            Kanji {
                visible: Kisetsu.ko.kanji !== ""
                text: Kisetsu.ko.kanji
                size: 16
                font.weight: Font.Medium
                color: Theme.colors.accent2
            }
            OText {
                visible: Kisetsu.ko.kanji !== ""
                text: Kisetsu.ko.es.charAt(0).toLowerCase() + Kisetsu.ko.es.slice(1)
                size: 16
                color: Theme.colors.textMuted
            }
        }

        // every screen has a field (the keyboard follows the pointer's output): full on the primary, compact under
        // the clock on the others
        PasswordField {
            id: field
            x: root.primary ? 104 : (root.width - width) / 2
            y: root.primary ? 600 : clock.y + clock.height + 70
            visible: !root.ghost || root.primary
            interactive: root.interactive && !root.ghost && !Lock.unlocking
            busy: Lock.checking
            error: Lock.message !== ""
            waitUntil: Lock.waitUntil
            live: root.live
            onTextChanged: if (interactive) Lock.typing = text !== ""
            onKeyed: i => logo.press(i)
            onSubmitted: secret => {
                if (Lock.submit(secret))
                    field.clear();
            }
            Keys.onPressed: capsCheck.restart()
            Keys.onReleased: capsCheck.restart()
        }

        // hints: errors first, then fingerprint · layout · caps · notifications · locked since
        Flow {
            x: 110
            y: 676
            width: 640
            spacing: 18
            visible: root.primary

            Hint {
                visible: Lock.message !== ""
                icon: "error"
                text: Lock.message + (Lock.failures >= 3 ? " · " + Lock.failures + " intentos" : "")
                tint: Theme.colors.error
            }
            Hint {
                visible: root.capsOn
                icon: "keyboard_capslock"
                text: "Mayúsculas activadas"
                tint: Theme.colors.warning
            }
            Hint {
                visible: Lock.fingerprint
                icon: "fingerprint"
                text: Lock.fingerHint !== "" ? Lock.fingerHint : "Toca el lector de huellas"
            }
            Hint {
                icon: "keyboard"
                text: root.layoutCode
            }
            Hint {
                visible: Notifs.unread > 0
                icon: "notifications"
                text: Notifs.unread === 1 ? "1 notificación" : Notifs.unread + " notificaciones"
            }
            Hint {
                icon: "lock_clock"
                text: root.lockedFor
            }
        }

        // ---------------------------------------------------------- right: proverb in 縦書き
        Column {
            anchors { right: parent.right; rightMargin: 150; top: parent.top; topMargin: 150 }
            visible: root.primary && Lock.proverb.jp !== ""
            spacing: 0

            Row {
                anchors.right: parent.right
                spacing: 22
                // romaji runs downwards, rotated like vertical-rl Latin text
                Item {
                    width: romaji.implicitHeight
                    height: romaji.implicitWidth
                    OText {
                        id: romaji
                        anchors.centerIn: parent
                        rotation: 90
                        text: Lock.proverb.romaji
                        size: 13
                        color: Theme.colors.textMuted
                        font.letterSpacing: 13 * 0.12
                    }
                    y: 6
                }
                Tategaki {
                    text: Lock.proverb.jp
                    // 40 px (step 1.32 × size) fits 12 glyphs above the hanko and translation; longer ones shrink
                    size: Math.min(40, Math.floor((root.height - 350) / (Math.max(1, Array.from(text).length) * 1.32)))
                }
            }
            // CSS vertical-rl keeps the .32em tracking after the last glyph, plus margin-top 8
            Item { width: 1; height: 8 + 40 * 0.27 }
            // 殻 hanko (brush, rotated -4°)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -2
                width: 46
                height: 46
                radius: 9
                rotation: -4
                color: Theme.colors.accent
                border.width: 1.5
                border.color: "#38ffffff"
                antialiasing: true
                Kanji {
                    anchors.centerIn: parent
                    brush: true
                    text: "殻"
                    size: 26
                    font.weight: Font.Normal
                    color: Theme.colors.accentInk
                }
            }
            Item { width: 1; height: 26 }
            OText {
                anchors.right: parent.right
                width: 300
                horizontalAlignment: Text.AlignRight
                text: "«" + Lock.proverb.es + "»"
                size: 14
                font.italic: true
                color: Theme.mix(Theme.colors.text, Theme.colors.textMuted, 0.45)
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideNone
                lineHeightMode: Text.FixedHeight
                lineHeight: 20                 // 14 px × 1.45 (mockup)
            }
        }

        // ---------------------------------------------------------- bottom-left: mini player
        LockPlayer {
            x: 104
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56
            visible: root.primary && Media.active && Settings.data.lock.showMedia
        }
    }

    // ------------------------------------------------------------------ bits of state
    readonly property string layoutCode: {
        const names = Niri.keyboardLayouts.names ?? [];
        const n = names[Niri.keyboardLayouts.current_idx ?? 0] ?? "";
        const known = { "Spanish": "ES", "English (US)": "US", "English (UK)": "UK", "French": "FR", "German": "DE",
                        "Arabic": "AR", "Japanese": "JP", "Portuguese": "PT", "Italian": "IT" };
        return known[n] ?? (n !== "" ? n.slice(0, 2).toUpperCase() : "ES");
    }
    readonly property string longDate: Qt.locale("es_ES").toString(Time.now, "dddd, d 'de' MMMM")
    readonly property string lockedFor: {
        const m = Math.floor((Time.now.getTime() - Lock.lockedAt) / 60000);
        return m < 1 ? "Bloqueado ahora" : m < 60 ? "Bloqueado hace " + m + " min"
             : "Bloqueado hace " + Math.floor(m / 60) + " h " + (m % 60) + " min";
    }

    // Caps Lock: the keyboard LEDs in sysfs, read only when a key goes down/up (never polled)
    property bool capsOn: false
    Timer {
        id: capsCheck
        interval: 120
        onTriggered: caps.running = true
    }
    Process {
        id: caps
        command: ["sh", "-c", "cat /sys/class/leds/input*::capslock/brightness 2>/dev/null"]
        running: root.primary
        stdout: StdioCollector {
            onStreamFinished: root.capsOn = /[1-9]/.test(text)
        }
    }

    Connections {
        target: Lock
        function onFailed() {
            field.shake();
            logo.shake();
        }
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "opacity"
        to: 0
        duration: Motion.d(300)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.accel
        onFinished: root.dissolved()
    }

    component Hint: Row {
        id: hint
        property string icon
        property string text
        property color tint: Theme.mix(Theme.colors.textMuted, Theme.colors.text, 0.1)
        spacing: 6
        OIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: hint.icon
            size: 18
            color: hint.tint
        }
        OText {
            anchors.verticalCenter: parent.verticalCenter
            text: hint.text
            size: Theme.font.small
            color: hint.tint
        }
    }
}
