pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// 縁側 Engawa — main page (mockup 02): header · tiles · power modes · sliders · profiles · media · battery.
ColumnLayout {
    id: root
    spacing: 0
    signal openPage(string page)

    // ── header ───────────────────────────────────────────────────────────────────────────────
    property string user: Quickshell.env("USER") ?? ""
    property string host: ""
    property string uptime: ""
    function refreshUptime(): void {
        upFile.reload();
    }
    FileView {
        id: upFile
        path: "/proc/uptime"
        onLoaded: {
            const s = parseFloat(text().split(" ")[0]);
            const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
            root.uptime = (h > 0 ? h + " h " : "") + m + " min";
        }
    }
    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim()
    }
    Component.onCompleted: refreshUptime()

    RowLayout {
        Layout.fillWidth: true
        spacing: 11
        Image {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            source: Paths.url(Paths.asset("logo/png/ocarinashell-icon-128.png"))
            sourceSize: Qt.size(76, 76)
            smooth: true
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            OText {
                text: root.user.charAt(0).toUpperCase() + root.user.slice(1)
                size: 15
                font.weight: Font.DemiBold
            }
            OText {
                Layout.fillWidth: true
                text: "Encendido " + root.uptime + (root.host ? " · " + root.host : "")
                size: 12
                color: Theme.colors.textMuted
            }
        }
        IconButton { icon: "settings"; label: "Ajustes"; onClicked: { Panels.close(); Quickshell.execDetached(["ocarina", "settings"]); } }
        IconButton { icon: "lock"; label: "Bloquear"; onClicked: { Panels.close(); Quickshell.execDetached(["ocarina", "lock"]); } }
        IconButton { icon: "power_settings_new"; label: "Energía"; danger: true; onClicked: { Panels.close(); Quickshell.execDetached(["ocarina", "power"]); } }
    }

    // ── tiles ────────────────────────────────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: 14
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        Tile {
            Layout.fillWidth: true
            visible: Net.available
            icon: Net.wired ? "lan" : Net.icon
            title: Net.wired ? "Red" : "Wi-Fi"
            subtitle: Net.wired ? "Cable conectado" : Net.connected ? Net.ssid : (Net.backend?.wifiEnabled ? "Sin conectar" : "Desactivado")
            watermark: "網"
            on: Net.connected || (Net.backend?.wifiEnabled ?? false)
            onToggled: Net.toggleWifi()
            onDetails: root.openPage("wifi")
        }
        Tile {
            Layout.fillWidth: true
            visible: Bt.available
            icon: Bt.connected > 0 ? "bluetooth_connected" : "bluetooth"
            title: "Bluetooth"
            subtitle: !Bt.enabled ? "Desactivado" : Bt.connected > 0 ? Bt.summary : "Sin dispositivos"
            watermark: "青"
            on: Bt.enabled
            onToggled: Bt.toggle()
            onDetails: root.openPage("bluetooth")
        }
        Tile {
            Layout.fillWidth: true
            icon: "do_not_disturb_on"
            title: "No molestar"
            subtitle: Notifs.scheduleActive ? "Por horario" : Notifs.dnd ? "Activado" : "Desactivado"
            watermark: "静"
            on: Notifs.dnd
            onToggled: Notifs.setDnd("toggle")
            onDetails: Panels.show("notifications", "")
        }
        Tile {
            Layout.fillWidth: true
            icon: "nightlight"
            title: "Luz nocturna"
            subtitle: NightLight.subtitle
            watermark: "夜"
            on: NightLight.on
            onToggled: NightLight.toggle()
            onDetails: root.openPage("night")
        }
        Tile {
            Layout.fillWidth: true
            icon: "coffee"
            title: "Despierto"
            subtitle: Idle.inhibit ? "No suspender · on" : "No suspender · off"
            watermark: "醒"
            on: Idle.inhibit
            hasDetails: false
            onToggled: Idle.toggleInhibit()
        }
        Tile {
            Layout.fillWidth: true
            icon: "screen_record"
            title: "Grabar"
            subtitle: Recorder.recording ? "Grabando… pulsa para parar" : "Región o pantalla"
            watermark: "録"
            on: Recorder.recording
            onToggled: Recorder.recording ? Recorder.stop() : Recorder.start(false)
            onDetails: root.openPage("record")
        }
        Tile {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            visible: Vpn.available && Settings.data.extras.vpnTile
            icon: "vpn_lock"
            title: "VPN"
            subtitle: Vpn.active !== "" ? Vpn.active : "Desconectada · " + Vpn.names.length + " configuradas"
            watermark: "護"
            on: Vpn.active !== ""
            onToggled: Vpn.toggle()
            onDetails: root.openPage("vpn")
        }
    }

    // ── power modes ──────────────────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 8
        ModeCard {
            Layout.fillWidth: true
            kind: "shinobi"
            on: Modes.shinobi
            onClicked: Quickshell.execDetached(["ocarina", "shinobi", "toggle"])
        }
        ModeCard {
            Layout.fillWidth: true
            kind: "oni"
            on: Modes.oni
            onClicked: Quickshell.execDetached(["ocarina", "oni", "toggle"])
        }
    }
    // 滑 Fluido (Nameraka): hidden when the system cannot do it at all (self-test 10–12)
    FlowCard {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: Nameraka.cardVisible
        onOpenPage: root.openPage("fluido")
    }

    // ── sliders ──────────────────────────────────────────────────────────────────────────────
    OSlider {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: Audio.available
        label: Audio.muted ? "Volumen, silenciado" : "Volumen"
        icon: Audio.muted ? "volume_off" : "volume_up"
        value: Audio.muted ? 0 : Audio.volume
        onMoved: v => Audio.setVolume(v)
        onSecondary: root.openPage("audio")
        // tiny affordance to the audio page (right click and the Menu key work too); a bare icon like the mockup,
        // focusable as a button (IconButton's 34 px tile would cover the fill)
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 52
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 15                 // the icon's own size; the focus ring sits 4 px outside
            implicitHeight: 15
            radius: 4
            color: "transparent"
            OIcon {
                anchors.centerIn: parent
                icon: "tune"
                size: 15
                color: Theme.colors.textDim
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPage("audio")
            }
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Ajustes de audio"
            Keys.onReturnPressed: root.openPage("audio")
            Keys.onSpacePressed: root.openPage("audio")
            FocusRing {}
        }
    }
    Repeater {
        // keyed by output name: entries are replaced on every change, the delegates must not be
        model: ScriptModel {
            values: Brightness.entries.filter(e => e.kind !== "none").map(e => e.name)
        }
        delegate: OSlider {
            id: bs
            required property string modelData
            readonly property var e: Brightness.entry(modelData) ?? { name: modelData, label: modelData, kind: "none", pct: 100 }
            Layout.fillWidth: true
            Layout.topMargin: 8
            icon: "light_mode"
            label: "Brillo"
            // one screen: just the value; several: device icon + name (mockup 02)
            deviceLabel: Brightness.entries.length > 1 ? e.label + (e.kind === "soft" ? " · SW" : "") : ""
            deviceIcon: e.kind === "internal" ? "laptop" : "desktop_windows"
            value: e.pct / 100
            onMoved: v => Brightness.set(Math.round(v * 100), bs.shift ? "all" : bs.modelData)
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { Anim {} }
        }
    }
    // keyboard backlight: the ThinkPad has exactly 3 levels (0 · 1 · 2, firmware) → three buttons like the power
    // profiles (Ayoub, fase 15); a keyboard with more levels keeps the slider
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: KbdLight.available && KbdLight.max === 2
        spacing: 8
        // what the three buttons are for: the keyboard, in a tile as tall as the control
        Rectangle {
            implicitWidth: 42
            implicitHeight: 42
            radius: 14
            color: Theme.colors.surface1
            border.width: 1
            border.color: Theme.colors.outline
            OIcon {
                anchors.centerIn: parent
                icon: "keyboard"
                fill: true
                optical: true
                size: 20
                color: KbdLight.level > 0 ? Theme.colors.text : Theme.colors.textMuted
            }
        }
        Segmented {
            Layout.fillWidth: true
            current: String(KbdLight.level)
            options: [
                { id: "0", kanji: "消", label: "Apagada" },
                { id: "1", kanji: "弱", label: "Baja" },
                { id: "2", kanji: "強", label: "Alta" }
            ]
            onPicked: id => KbdLight.set(Number(id))
            Accessible.name: "Luz del teclado"
        }
    }
    OSlider {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: KbdLight.available && KbdLight.max !== 2
        icon: "backlight_high"            // magnitude on the left, device + name on the right (mockup 02)
        deviceIcon: "keyboard"
        deviceLabel: "Teclado"
        label: "Luz del teclado"
        step: 1 / Math.max(1, KbdLight.max)
        value: KbdLight.max > 0 ? KbdLight.level / KbdLight.max : 0
        valueText: Math.round(value * 100) + " %"
        onMoved: v => KbdLight.set(Math.round(v * KbdLight.max))
    }

    // ── profiles ─────────────────────────────────────────────────────────────────────────────
    Segmented {
        Layout.fillWidth: true
        Layout.topMargin: 8
        current: Power.profile
        options: [
            { id: "power-saver", kanji: "省", label: "Ahorro" },
            { id: "balanced", kanji: "均", label: "Equilibrado" },
            { id: "performance", kanji: "速", label: "Rendimiento" }
        ]
        onPicked: id => Power.setProfile(id, false)
    }

    // ── media ────────────────────────────────────────────────────────────────────────────────
    MediaCard {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: Media.active
    }

    // ── battery footer ───────────────────────────────────────────────────────────────────────
    readonly property real watts: Math.abs(Power.changeRate)
    property int chargeEnd: 0
    FileView {
        path: "/sys/class/power_supply/BAT0/charge_control_end_threshold"
        printErrors: false
        onLoaded: root.chargeEnd = parseInt(text()) || 0
    }

    function duration(sec: real): string {
        if (!sec || sec <= 0)
            return "";
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
        Layout.rightMargin: 2
        visible: Power.hasBattery
        spacing: 10
        OIcon {
            icon: Power.charging ? "battery_charging_full" : Power.percent > 0.85 ? "battery_full"
                : "battery_" + Math.max(0, Math.min(6, Math.round(Power.percent * 6))) + "_bar"
            size: 18
            color: Power.low ? Theme.colors.error : Theme.colors.textMuted
        }
        OText {
            text: Math.round(Power.percent * 100) + " %"
            size: 15
            font.weight: Font.DemiBold
            tabular: true
        }
        OText {
            Layout.fillWidth: true
            size: 12.5
            color: Theme.colors.textMuted
            tabular: true
            text: {
                const parts = [];
                if (Power.full)
                    parts.push("Cargada");
                else if (Power.charging && Power.timeToFull > 0)
                    parts.push(root.duration(Power.timeToFull) + " hasta llenar");
                else if (Power.discharging && Power.timeToEmpty > 0)
                    parts.push(root.duration(Power.timeToEmpty) + " restantes" + (Power.onBattery ? "" : " · enchufado"));
                else if (!Power.onBattery)
                    parts.push(Power.charging ? "Cargando" : "Enchufado · sin cargar");
                if (root.watts > 0.05)
                    parts.push(root.watts.toFixed(1).replace(".", ",") + " W");
                return parts.join(" · ");
            }
        }
        Chip {
            // the real threshold from the kernel (phase 10 applies the 75–80 % setting; until then it may be 100)
            visible: root.chargeEnd > 0 && root.chargeEnd < 100
            kanji: "限"
            text: "Límite " + root.chargeEnd + " %"
        }
    }
}
