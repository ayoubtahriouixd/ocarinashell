pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.engawa
import qs.components
import qs.services

// Small detail pages: 夜 night light, 録 recording and 護 VPN. `page` picks which one.
ColumnLayout {
    id: root
    property string page: "night"
    spacing: 10
    signal back

    PageHeader {
        Layout.fillWidth: true
        title: root.page === "night" ? "Luz nocturna" : root.page === "record" ? "Grabar pantalla" : "VPN"
        kanji: root.page === "night" ? "夜" : root.page === "record" ? "録" : "護"
        hasSwitch: root.page === "night"
        checked: NightLight.on
        onBack: root.back()
        onToggled: NightLight.toggle()
    }

    // ── night light ──
    Segmented {
        visible: root.page === "night"
        Layout.fillWidth: true
        // when off, the last mode stays marked (dimmed) so it is clear what turning it on will do
        current: NightLight.on ? NightLight.mode : (Settings.data.display.nightLight.lastMode ?? "auto")
        opacity: NightLight.on ? 1 : 0.4
        options: [
            { id: "auto", kanji: "陽", label: "Automática" },
            { id: "schedule", kanji: "時", label: "Horario" },
            { id: "manual", kanji: "常", label: "Siempre" }
        ]
        onPicked: id => NightLight.setMode(id)
    }
    OText {
        visible: root.page === "night"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        size: 12
        color: Theme.colors.textMuted
        text: NightLight.mode === "auto" ? "Del atardecer (" + Kisetsu.sunsetText + ") al amanecer (" + Kisetsu.sunriseText + ") en " + Settings.data.weather.place + "."
            : NightLight.mode === "schedule" ? "De " + Settings.data.display.nightLight.from + " a " + Settings.data.display.nightLight.to
            : NightLight.mode === "manual" ? "Siempre cálida mientras esté activa" : "Desactivada"
    }
    OSlider {
        visible: root.page === "night"
        Layout.fillWidth: true
        icon: "thermostat"
        label: "Temperatura de la luz nocturna"
        showValue: false
        // local value while dragging; the setting (and the wlsunset restart) only on release
        property int temp: Settings.data.display.nightLight.temp
        deviceLabel: temp + " K"
        value: (6000 - temp) / (6000 - 2500)
        onMoved: v => temp = Math.round((6000 - v * 3500) / 100) * 100
        onReleased: Settings.set("display.nightLight.temp", temp)
    }

    // ── recording ──
    RowLayout {
        visible: root.page === "record"
        Layout.fillWidth: true
        spacing: 8
        OButton { Layout.fillWidth: true; text: "Pantalla completa"; icon: "fullscreen"; primary: true; onClicked: Recorder.start(false) }
        OButton { Layout.fillWidth: true; text: "Región"; icon: "crop_free"; onClicked: Recorder.start(true) }
    }
    OText {
        visible: root.page === "record"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        size: 12
        color: Theme.colors.textMuted
        text: Recorder.recording ? "Grabando… la isla muestra 録. Para parar: este mosaico o Mod+Alt+R."
            : "Se guarda en ~/Vídeos/Grabaciones. Atajo: Mod+Alt+R."
    }

    // ── VPN ──
    Repeater {
        model: root.page === "vpn" ? Vpn.names : []
        delegate: ListRow {
            required property string modelData
            Layout.fillWidth: true
            icon: "vpn_lock"
            title: modelData
            active: Vpn.active === modelData
            onClicked: Vpn.active === modelData ? Vpn.toggle() : Vpn.up(modelData)
        }
    }
}
