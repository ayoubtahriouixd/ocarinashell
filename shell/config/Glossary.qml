pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Japanese glossary for the UI (assets/data/kanji-ui.json): numerals, weekdays, months, modules…
// Kanji are ornament next to the Spanish label, never instead of it (docs/00-VISION).
Singleton {
    id: root

    property var g: ({})
    readonly property bool ready: g.numerals !== undefined

    function numeral(n: int): string {
        const a = g.numerals ?? [];
        return n >= 0 && n < a.length ? a[n] : String(n);
    }
    // 1–99 in kanji (十四, 二十三…), used for dates
    function number(n: int): string {
        if (n <= 20)
            return numeral(n);
        const t = Math.floor(n / 10), u = n % 10;
        return (t > 1 ? numeral(t) : "") + "十" + (u ? numeral(u) : "");
    }
    function weekday(d: int): var {
        return (g.weekdays ?? [])[d] ?? { kanji: "", es: "" };
    }
    function month(m: int): var {
        return (g.months ?? [])[m] ?? { n: "", wafu: "", es: "" };
    }
    function profile(id: string): var {
        return (g.powerProfiles ?? {})[id] ?? { kanji: "均", es: "" };
    }
    function module(id: string): var {
        return (g.modules ?? {})[id] ?? { kanji: "", es: id };
    }

    FileView {
        path: Paths.asset("data/kanji-ui.json")
        printErrors: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.g = JSON.parse(text());
            } catch (e) {
                console.warn("Glossary: kanji-ui.json no válido:", e);
            }
        }
    }
}
