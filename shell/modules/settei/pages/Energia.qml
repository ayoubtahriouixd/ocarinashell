pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import QtQuick.Window
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 電源 Energía: power profile, battery state and a consumption graph (UPower history over D-Bus, read once when
// the page opens and every 5 min while it stays open), charge limit (applied by the phase-10 helper), thresholds.
SetteiPage {
    id: page
    subtitle: "Perfil de energía, batería, límite de carga y avisos. La gráfica sale del historial de UPower."
    resetPaths: ["power"]

    readonly property var pw: Settings.data.power
    property var rate: []          // W, oldest first
    property var charge: []        // %, oldest first
    property real maxRate: 30

    function hm(sec: real): string {
        if (!(sec > 0))
            return "";
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
    function parseHistory(txt: string, kind: string): void {
        try {
            // [[time, value, state], …] newest first; keep the last 4 h in 3-min buckets
            const rows = JSON.parse(txt).data[0].filter(r => r[2] !== 0).reverse();
            const now = Date.now() / 1000, out = [];
            for (let b = 0; b < 80; b++) {
                const t0 = now - 4 * 3600 + b * 180, t1 = t0 + 180;
                const vs = rows.filter(r => r[0] >= t0 && r[0] < t1).map(r => r[1]);
                if (vs.length)
                    out.push(vs.reduce((a, c) => a + c, 0) / vs.length);
                else if (out.length)
                    out.push(out[out.length - 1]);
            }
            if (kind === "rate") {
                page.rate = out;
                page.maxRate = Math.max(10, Math.ceil(Math.max(...out, 0) / 5) * 5);
            } else {
                page.charge = out;
            }
        } catch (e) {}
    }
    // the battery UPower reports (BAT0, BAT1…), not a fixed name
    readonly property string bat: Power.nativePath || "BAT0"
    readonly property string upowerPath: "/org/freedesktop/UPower/devices/battery_" + bat.replace(/[^A-Za-z0-9_]/g, "_")
    Process {
        id: histRate
        running: true
        command: ["busctl", "--json=short", "call", "org.freedesktop.UPower", page.upowerPath,
                  "org.freedesktop.UPower.Device", "GetHistory", "suu", "rate", "14400", "160"]
        stdout: StdioCollector { onStreamFinished: page.parseHistory(text, "rate") }
    }
    Process {
        id: histCharge
        running: true
        command: ["busctl", "--json=short", "call", "org.freedesktop.UPower", page.upowerPath,
                  "org.freedesktop.UPower.Device", "GetHistory", "suu", "charge", "14400", "160"]
        stdout: StdioCollector { onStreamFinished: page.parseHistory(text, "charge") }
    }
    // refresh every 5 min only while the window is visible and outside Shinobi
    Timer {
        interval: 300000
        repeat: true
        running: page.visible && (page.Window.window?.visible ?? false) && !Modes.shinobi
        onTriggered: { histRate.running = true; histCharge.running = true; }
    }
    // what the kernel does now (ocarina-powerctl status, read by PowerCtl after every change)
    readonly property string kernelLimit: PowerCtl.status.charge?.end !== undefined && PowerCtl.status.charge?.end !== null
        ? String(PowerCtl.status.charge.end) : ""
    Component.onCompleted: PowerCtl.probe()

    SectionTitle { text: "Perfil" }
    Card {
        SRow {
            title: "Perfil de energía"
            sub: Power.profile === "power-saver" ? "Ahorro: CPU contenida, más batería" : Power.profile === "performance" ? "Rendimiento: CPU y GPU sin freno" : "Equilibrado: lo normal"
            Segmented {
                Layout.preferredWidth: 380
                options: [{ id: "power-saver", kanji: "省", label: "Ahorro" }, { id: "balanced", kanji: "均", label: "Equilibrado" },
                          { id: "performance", kanji: "速", label: "Rendimiento" }]
                current: Power.profile
                onPicked: id => Power.setProfile(id, false)
            }
        }
    }

    SectionTitle { text: "Batería · últimas 4 horas" }
    Card {
        padTop: 14
        padBottom: 14
        RowLayout {
            width: parent.width
            spacing: 0
            ColumnLayout {
                Layout.leftMargin: 18
                Layout.preferredWidth: 220
                spacing: 6
                OText {
                    text: Math.round(Power.percent * 100) + " %"
                    size: Theme.font.h1
                    font.weight: Font.DemiBold
                    tabular: true
                }
                OText {
                    text: Power.charging ? "Cargando" + (page.hm(Power.timeToFull) ? " · llena en " + page.hm(Power.timeToFull) : "")
                        : Power.full ? "Llena" : Power.discharging ? "Quedan " + (page.hm(Power.timeToEmpty) || "—") : "Enchufado"
                    size: 12.5
                    color: Theme.colors.textMuted
                }
                Chip {
                    Layout.topMargin: 4
                    kanji: "電"
                    text: page.rate.length ? page.rate[page.rate.length - 1].toFixed(1).replace(".", ",") + " W ahora" : "sin datos"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 18
                spacing: 4
                OText { text: "Consumo (W) · máx. " + page.maxRate + " W"; size: 11.5; color: Theme.colors.textDim }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    values: page.rate
                    max: page.maxRate
                    count: 80
                }
                OText { text: "Carga (%)"; size: 11.5; color: Theme.colors.textDim; Layout.topMargin: 4 }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    values: page.charge
                    max: 100
                    count: 80
                    color: Theme.colors.success
                }
            }
        }
    }

    SectionTitle { text: "Cuidado de la batería" }
    Card {
        ToggleRow {
            title: "Límite de carga"
            sub: "Cargar solo hasta " + page.pw.chargeLimit.end + " % y volver a cargar por debajo de " + page.pw.chargeLimit.start
                + " % · ahora el sistema para en " + (page.kernelLimit || "—") + " %"
                + (!PowerCtl.available ? " · necesita el ayudante: sudo bash scripts/install-system.sh"
                   : PowerCtl.failedCharge !== "" ? " · el sistema rechazó el cambio" : "")
            key: "power.chargeLimit.enabled"
        }
        SliderRow {
            title: "Parar de cargar en"
            key: "power.chargeLimit.end"
            dimmed: !page.pw.chargeLimit.enabled
            from: 60; to: 100; stepSize: 5
            format: v => Math.round(v) + " %"
        }
        SliderRow {
            title: "Volver a cargar por debajo de"
            key: "power.chargeLimit.start"
            dimmed: !page.pw.chargeLimit.enabled
            from: 40; to: 95; stepSize: 5
            format: v => Math.round(v) + " %"
        }
    }

    SectionTitle { text: "Avisos y automatismos" }
    Card {
        SliderRow {
            title: "Batería baja"
            sub: "Aviso y anillo rojo en la barra"
            key: "power.lowBattery"
            from: 5; to: 30; stepSize: 1
            format: v => Math.round(v) + " %"
        }
        SliderRow {
            title: "Entrar en 忍 Shinobi solo"
            sub: "0 = nunca"
            key: "power.autoShinobiAt"
            from: 0; to: 30; stepSize: 1
            format: v => v < 1 ? "nunca" : Math.round(v) + " %"
        }
        ToggleRow {
            title: "Preguntar antes"
            sub: "Un aviso con «Activar / Ahora no»; apagado, entra solo y te avisa"
            key: "power.autoShinobiAsk"
            dimmed: page.pw.autoShinobiAt < 1
        }
        ToggleRow { title: "Salir de Shinobi al enchufar"; key: "power.exitShinobiOnAC" }
    }
}
