pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Clock (minute precision unless seconds are shown). The minute tick is the shell's only "heartbeat": Hogo, focus
// blocks and Kisetsu hang from it instead of owning timers (docs/04-RENDIMIENTO rule 1).
Singleton {
    id: root

    readonly property date now: clock.date
    readonly property bool h24: Settings.data.bar.clock24
    readonly property string hhmm: Qt.formatTime(now, (h24 ? "HH:mm" : "h:mm") + (Settings.data.bar.showSeconds && !Modes.quiet && !Lock.active ? ":ss" : ""))
    readonly property int dayOfMonth: now.getDate()
    readonly property int weekday: now.getDay()
    readonly property int month: now.getMonth()
    readonly property string dayKey: now.getFullYear() + "-" + month + "-" + dayOfMonth

    // 水 14 · 神無月 · 十四日 · 水曜日
    readonly property string shortDay: Glossary.weekday(weekday).kanji + " " + dayOfMonth
    readonly property string kanjiDate: Glossary.month(month).wafu + " · " + Glossary.number(dayOfMonth) + "日 · "
        + Glossary.weekday(weekday).kanji + "曜日"
    readonly property string spanishDate: Qt.locale("es_ES").toString(now, "dddd d 'de' MMMM")

    signal minuteTick
    // changes once a minute even with seconds shown (views that only need minutes bind to this)
    property date minute: new Date()
    signal dayChanged

    onDayKeyChanged: dayChanged()

    // SystemClock notifies `date` for every unit of its precision: with seconds shown, filter to real minutes
    property int lastMinute: -1
    SystemClock {
        id: clock
        // seconds only while they can be seen (rule 7): never in Shinobi or under the lock
        precision: Settings.data.bar.showSeconds && !Modes.quiet && !Lock.active ? SystemClock.Seconds : SystemClock.Minutes
        onDateChanged: {
            const m = date.getHours() * 60 + date.getMinutes();
            if (m !== root.lastMinute) {
                root.lastMinute = m;
                root.minute = root.now;
                root.minuteTick();
            }
        }
    }
}
