pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 集中 Shūchū — focus blocks (docs/07-IDEAS). Minute precision from Time's tick: no timer of its own.
// During a block: Do-not-disturb on (restored afterwards). At the end: an ocarina note and «休憩 · descanso».
// Today's blocks (Koyomi ●●○) and the running block live in ~/.local/state/ocarinashell/focus.json, so a block
// survives shell reloads and restarts (resumed, or finished — restoring Do-not-disturb — if it ended meanwhile).
Singleton {
    id: root

    property bool active: false
    property int minutes: 0
    property double endsAt: 0
    property int remaining: 0          // minutes left
    readonly property real progress: active && minutes > 0 ? 1 - remaining / minutes : 0
    property bool dndBefore: false
    property var today: ({ day: "", done: 0 })

    function start(min: int): void {
        if (min <= 0)
            min = Settings.data.focus.minutes;
        minutes = min;
        endsAt = Date.now() + min * 60000;
        remaining = min;
        if (Settings.data.focus.dnd) {
            if (!active)
                dndBefore = Settings.data.notifications.dnd;   // a new block over a running one keeps the original
            Settings.set("notifications.dnd", true);
        }
        active = true;
        persist();
        Osd.show("info", 0, "集中 · foco " + min + " min", "timer");
    }
    function persist(): void {
        store.setText(JSON.stringify({ day: today.day, done: today.done,
            block: active ? { endsAt: endsAt, minutes: minutes, dndBefore: dndBefore } : null }) + "\n");
    }
    function stop(): void {
        if (!active)
            return;
        active = false;
        if (Settings.data.focus.dnd)
            Settings.set("notifications.dnd", dndBefore);
        persist();
    }
    function finish(): void {
        stop();
        // counted on the day the block ended (it may have ended yesterday while the shell was down)
        const end = new Date(Math.min(Date.now(), endsAt || Date.now()));
        const key = end.getFullYear() + "-" + end.getMonth() + "-" + end.getDate();
        today = { day: key, done: (today.day === key ? today.done : 0) + 1 };
        persist();
        Sounds.play("tick");
        Quickshell.execDetached(["notify-send", "-a", "OcarinaShell", "-i", "alarm-clock",
            "休憩 · descanso " + Settings.data.focus.breakMinutes + " min",
            "Bloque de " + minutes + " min terminado. Para otro: ocarina focus " + minutes]);
    }
    function status(): string {
        return active ? JSON.stringify({ remaining: remaining, minutes: minutes }) : "off";
    }

    Connections {
        target: Time
        function onMinuteTick() {
            if (!root.active)
                return;
            root.remaining = Math.max(0, Math.ceil((root.endsAt - Date.now()) / 60000));
            if (root.remaining <= 0)
                root.finish();
        }
    }
    // the last minute can end between ticks: one single-shot timer only while a block is active
    Timer {
        running: root.active
        interval: Math.max(1000, root.endsAt - Date.now())
        onTriggered: if (root.active && Date.now() >= root.endsAt - 500) root.finish()
    }

    FileView {
        id: store
        atomicWrites: true
        path: Paths.state + "/focus.json"
        printErrors: false
        onLoaded: {
            let d;
            try {
                d = JSON.parse(text());
            } catch (e) {
                return;
            }
            if (!d || typeof d !== "object")
                return;
            root.today = { day: d.day ?? "", done: d.done ?? 0 };
            const b = d.block;
            if (b && !root.active) {
                root.minutes = b.minutes;
                root.endsAt = b.endsAt;
                root.dndBefore = b.dndBefore;
                root.active = true;
                if (Date.now() >= b.endsAt)
                    root.finish();          // ended while the shell was down: count it, restore DND
                else
                    root.remaining = Math.ceil((b.endsAt - Date.now()) / 60000);
            }
        }
    }
}
