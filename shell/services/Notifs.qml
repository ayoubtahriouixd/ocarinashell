pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 文 Fumi — the notification server (org.freedesktop.Notifications) and its history.
// - popups: live Notification objects currently shown as toasts (max 3 visible, the rest counted as «+N»)
// - history: plain copies persisted in ~/.local/state/ocarinashell/notifications.json (100 max), grouped in the UI
// - DND: manual or by schedule (notifications.dndSchedule {from, to}); critical ones always show
// - while a window is fullscreen or DND is on, non-critical ones only "peek" in the island
// The NotificationServer lives in backends/NotifsBackend.qml (capa 3.1); urgencies are the spec's fixed numbers.
Singleton {
    id: root

    property QtObject server: null
    property string error: ""
    readonly property bool available: server !== null
    // org.freedesktop.Notifications urgency levels (fixed by the spec, = NotificationUrgency)
    readonly property int urgencyLow: 0
    readonly property int urgencyCritical: 2

    property var popups: []           // Notification objects (newest first)
    property var history: []          // { id, app, icon, summary, body, image, urgency, time }
    property int unread: 0
    readonly property bool dnd: Settings.data.notifications.dnd || (scheduleActive && !scheduleOverride) || oniDnd
    // 鬼 Oni: No molestar while it lasts (oni.dnd); critical ones still show, the setting itself is not touched
    // the switch (Engawa, NotifCenter) can still turn it off for the rest of this Oni
    property bool oniDndOverride: false
    readonly property bool oniDnd: Modes.oni && Settings.data.oni.dnd && !oniDndOverride
    Connections {
        target: Modes
        function onOniChanged() { root.oniDndOverride = false; }
    }
    property bool scheduleActive: false
    property bool scheduleOverride: false     // switched off by hand inside the scheduled window
    readonly property int timeoutMs: Math.max(2, Settings.data.notifications.timeout) * 1000

    signal peek(var notif)

    function urgencyName(u: int): string {
        return u === root.urgencyCritical ? "critical" : u === root.urgencyLow ? "low" : "normal";
    }

    // Body markup reduced to b/i/u/a/br (no <img>: remote images would be tracking pixels and file:// a local
    // read), links limited to http(s) and mailto. Applied before showing and before storing.
    function sanitize(html: string): string {
        if (!html)
            return "";
        return html.replace(/<img[^>]*>/gi, "")
            .replace(/<(?!\/?(b|i|u|br|a)(\s|>|\/))[^>]*>/gi, "")
            .replace(/href\s*=\s*(["'])(?!https?:|mailto:)[^"']*\1/gi, 'href="#"');
    }

    property int uidCounter: 0
    function add(n: var): void {
        const critical = n.urgency === root.urgencyCritical;
        // re-emitted after a shell reload: no sound, no toast (critical ones stay visible)
        if (n.lastGeneration && !critical) {
            n.expire();
            return;
        }
        if (!n.transient && !n.lastGeneration) {
            const app = n.appName || "Aplicación";
            const h = [{
                uid: Date.now() + "-" + (uidCounter++), id: n.id, app: app, icon: n.appIcon,
                summary: n.summary, body: sanitize(n.body), urgency: urgencyName(n.urgency), time: Date.now(),
                desktop: n.desktopEntry
            }].concat(history.filter(x => !(x.id === n.id && x.app === app && x.live)));
            h[0].live = true;            // replacements by id update this entry while the shell runs
            history = h.slice(0, 100);
            unread++;
            save();
        }
        // per-app (Settei → Notificaciones): mute = history only; silent = no sound
        const rule = Settings.data.notifications.perApp[n.appName || "Aplicación"] ?? {};
        if (rule.mute && !critical) {
            n.expire();
            return;
        }
        // the mode's own toast («覚醒») is the one notice that the mode's No molestar lets through
        const modeToast = n.appName.startsWith("Oni") && n.hints?.["x-ocarina-mode"] === "oni";
        if (dnd && !critical && !modeToast) {
            peek(n);
            n.expire();                  // the copy is in the history; do not keep a tracked object forever
            return;
        }
        n.tracked = true;
        // replacement by id: the server reuses the object, just bring it to the front
        popups = [n].concat(popups.filter(p => p !== n));
        if (!n.lastGeneration && (critical || !rule.silent))
            Sounds.play(critical ? "critical" : "notify");
        if (!(n.id in hooked)) {
            hooked[n.id] = true;
            n.closed.connect(() => {
                delete root.hooked[n.id];
                root.removePopup(n);
            });
        }
    }
    property var hooked: ({})          // ids whose `closed` is already connected (replacements reuse the object)

    // ── «take me there» (Ayoub, fase 15): a click on a notification ─────────────────────────────
    // 1. the app's own default action, while the notification is still alive (Chrome opens the tab, etc.);
    // 2. its window gets the focus: same app (desktop entry ↔ niri app-id), the one whose title mentions it, else the
    //    one used last; niri would not raise it for an action without an activation token;
    // 3. no window: OcarinaShell's own notices open their panel; another app is launched from its desktop entry.
    function windowFor(desktop: string, app: string, summary: string): var {
        const want = String(desktop || DesktopEntries.heuristicLookup(app)?.id || "").toLowerCase().replace(/\.desktop$/, "");
        if (want === "")
            return null;
        const s = String(summary || "").toLowerCase().trim();
        let best = null, bestScore = -1;
        for (const id in Niri.windows) {
            const w = Niri.windows[id];
            const a = String(w.app_id || "").toLowerCase();
            if (a !== want && !a.endsWith("." + want) && !want.endsWith("." + a))
                continue;
            const t = String(w.title || "").toLowerCase();
            const ts = (w.focus_timestamp?.secs ?? 0) + (w.focus_timestamp?.nanos ?? 0) / 1e9;
            const score = (s.length > 2 && t.indexOf(s) >= 0 ? 1e9 : 0) + ts;
            if (score > bestScore) {
                best = w;
                bestScore = score;
            }
        }
        return best;
    }
    // returns whether the app's own default action ran (a non-resident notification is closed — and destroyed — by
    // it: read everything first, never touch it afterwards)
    function goTo(n: var): bool {
        const app = String(n.appName ?? n.app ?? "");
        const desktop = String(n.desktopEntry ?? n.desktop ?? "");
        const summary = String(n.summary ?? "");
        const def = n?.actions?.find(a => a.identifier === "default") ?? null;
        if (def)
            def.invoke();
        const w = windowFor(desktop, app, summary);
        if (w) {
            Niri.focusWindow(w.id);
        } else if (!def) {
            if (app.startsWith("船"))
                Panels.show("fune", "");
            else if (app.startsWith("蛇"))
                Panels.show("snake", "");
            else {
                const e = DesktopEntries.byId(desktop) ?? null;
                if (e)
                    e.execute();
            }
        }
        return def !== null;
    }
    // a toast: go there and close it (the action already closed a non-resident one)
    function open(n: var): void {
        const resident = n.resident ?? false;
        if (!goTo(n) || resident)
            dismiss(n);
        else
            removePopup(n);
    }
    // an entry of the history: the live notification if it still exists (its action works), else the copy
    function openHistory(h: var): void {
        const live = h.live ? (server?.trackedNotifications.values ?? []).find(n => n.id === h.id) ?? null : null;
        Panels.close();
        if (live)
            open(live);
        else
            goTo(h);
    }

    function removePopup(n: var): void {
        popups = popups.filter(p => p !== n);
    }
    function dismiss(n: var): void {
        removePopup(n);
        n.dismiss();
    }
    // a power mode's own toast («Salir de Oni») is meaningless once the mode is over
    function dismissApp(prefix: string): void {
        for (const n of popups.filter(p => String(p.appName).startsWith(prefix)))
            dismiss(n);
    }
    function expire(n: var): void {
        removePopup(n);
        if (n.urgency !== root.urgencyCritical)
            n.expire();
    }
    function clearHistory(): void {
        history = [];
        unread = 0;
        save();
        for (const n of (server?.trackedNotifications.values ?? []).slice())
            n.dismiss();
        popups = [];
    }
    function removeHistory(uid: string): void {
        history = history.filter(x => x.uid !== uid);
        save();
    }
    function markRead(): void {
        unread = 0;
    }
    function setDnd(state: string): void {
        const want = state === "on" ? true : state === "off" ? false : !dnd;
        if (Modes.oni && Settings.data.oni.dnd)
            oniDndOverride = !want;          // Oni's No molestar is a layer: the switch lifts it, not the setting
        if (scheduleActive)
            scheduleOverride = !want;         // inside the schedule the switch wins until the window ends
        Settings.set("notifications.dnd", want && !scheduleActive);
        Osd.show("info", 0, root.dnd ? "No molestar activado" : "No molestar desactivado",
                 root.dnd ? "do_not_disturb_on" : "notifications");
    }

    function save(): void {
        // `live` only matters in memory; ids restart with the shell
        store.setText(JSON.stringify(history.map(x => { const c = Object.assign({}, x); delete c.live; return c; })) + "\n");
    }

    // DND schedule {from: "23:00", to: "07:00"}, checked on the minute tick
    function checkSchedule(): void {
        const s = Settings.data.notifications.dndSchedule;
        if (!s || !s.from || !s.to) {
            scheduleActive = false;
            return;
        }
        const toMin = t => parseInt(t.split(":")[0]) * 60 + parseInt(t.split(":")[1]);
        const now = Time.now.getHours() * 60 + Time.now.getMinutes();
        const a = toMin(s.from), b = toMin(s.to);
        const was = scheduleActive;
        scheduleActive = a <= b ? (now >= a && now < b) : (now >= a || now < b);
        if (was && !scheduleActive)
            scheduleOverride = false;
    }
    Connections {
        target: Time
        function onMinuteTick() { root.checkSchedule(); }
    }
    Component.onCompleted: {
        checkSchedule();
        const c = Qt.createComponent("backends/NotifsBackend.qml");
        if (c.status === Component.Ready) {
            server = c.createObject(root, { owner: root });
        } else {
            error = c.errorString();
            Health.fail("Fumi · notificaciones (Quickshell.Services.Notifications)", error);
        }
    }

    FileView {
        id: store
        atomicWrites: true
        path: Paths.state + "/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const h = JSON.parse(text());
                if (Array.isArray(h))
                    root.history = h.slice(0, 100).map((x, i) => Object.assign({ uid: "old-" + i }, x, { image: undefined }));
            } catch (e) {}
        }
    }
}
