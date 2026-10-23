pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 通知 Notificaciones: Do Not Disturb (manual and scheduled), time on screen, per-app rules.
SetteiPage {
    id: page
    subtitle: "No molestar, horario, cuánto se quedan los avisos y qué hace cada aplicación."
    resetPaths: ["notifications"]
    readonly property var nt: Settings.data.notifications
    readonly property var times: {
        const out = [];
        for (let h = 0; h < 24; h++)
            for (const m of ["00", "30"])
                out.push({ id: String(h).padStart(2, "0") + ":" + m, label: String(h).padStart(2, "0") + ":" + m });
        return out;
    }
    // apps seen in the history plus the ones with a rule
    readonly property var apps: {
        const s = {};
        for (const h of Notifs.history)
            s[h.app] = true;
        for (const k in nt.perApp)
            s[k] = true;
        return Object.keys(s).sort((a, b) => a.localeCompare(b));
    }
    function ruleOf(app: string): string {
        const r = nt.perApp[app] ?? {};
        return r.mute ? "mute" : r.silent ? "silent" : "normal";
    }
    function setRule(app: string, v: string): void {
        const p = Object.assign({}, nt.perApp);
        if (v === "normal")
            delete p[app];
        else
            p[app] = v === "mute" ? { mute: true } : { silent: true };
        Settings.set("notifications.perApp", p);
    }

    SectionTitle { text: "No molestar" }
    Card {
        ToggleRow { title: "No molestar"; sub: "Solo pasan los avisos críticos; el resto va al centro y asoma en la isla"; key: "notifications.dnd" }
        SRow {
            title: "Horario"
            sub: page.nt.dndSchedule ? "Cada día de " + page.nt.dndSchedule.from + " a " + page.nt.dndSchedule.to : "Sin horario"
            Dropdown {
                visible: !!page.nt.dndSchedule
                options: page.times
                current: page.nt.dndSchedule?.from ?? "23:00"
                label: "Desde"
                onPicked: id => { Settings.set("notifications.dndSchedule", { from: id, to: page.nt.dndSchedule.to }); Notifs.checkSchedule(); }
            }
            OText { visible: !!page.nt.dndSchedule; text: "a"; color: Theme.colors.textMuted }
            Dropdown {
                visible: !!page.nt.dndSchedule
                options: page.times
                current: page.nt.dndSchedule?.to ?? "07:00"
                label: "Hasta"
                onPicked: id => { Settings.set("notifications.dndSchedule", { from: page.nt.dndSchedule.from, to: id }); Notifs.checkSchedule(); }
            }
            Switch_ {
                checked: !!page.nt.dndSchedule
                label: "Horario de No molestar"
                onToggled: {
                    Settings.set("notifications.dndSchedule", page.nt.dndSchedule ? null : { from: "23:00", to: "07:00" });
                    Notifs.checkSchedule();
                }
            }
        }
    }
    SectionTitle { text: "Avisos" }
    Card {
        SliderRow { title: "Tiempo en pantalla"; sub: "Los críticos se quedan hasta que los cierras"; key: "notifications.timeout"; from: 3; to: 20; stepSize: 1; format: v => Math.round(v) + " s" }
        ToggleRow { title: "Sonido de los avisos"; sub: "El mismo interruptor que los sonidos de la interfaz"; key: "audio.uiSounds" }
    }
    SectionTitle { text: "Por aplicación" }
    Card {
        Repeater {
            model: page.apps
            delegate: SRow {
                id: ar
                required property string modelData
                title: modelData
                minHeight: 50
                Dropdown {
                    options: [{ id: "normal", label: "Normal" }, { id: "silent", label: "Sin sonido" }, { id: "mute", label: "Silenciada" }]
                    current: page.ruleOf(ar.modelData)
                    label: "Avisos de " + ar.modelData
                    menuWidth: 180
                    onPicked: id => page.setRule(ar.modelData, id)
                }
            }
        }
        SRow {
            visible: page.apps.length === 0
            title: "Todavía no ha llegado ningún aviso"
            sub: "Las apps aparecen aquí en cuanto envían el primero"
        }
    }
}
