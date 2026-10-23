pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// 二十四節気 · 七十二候 (assets/data/kisetsu-72.json). Recomputed only when the day changes.
// Start dates are the usual ones (±1 day depending on the year); good enough for an ornament.
Singleton {
    id: root

    property var table: ({ sekki: [], ko: [] })
    property var ko: ({ kanji: "", symbol: "", es: "", kana: "" })
    property var sekki: ({ kanji: "", es: "" })
    // 0 春 · 1 夏 · 2 秋 · 3 冬: six 節気 each, from 立春 (Glossary.g.seasons has the kanji)
    readonly property int season: root.ko.sekki === undefined ? -1 : Math.floor(root.ko.sekki / 6)

    function key(m: int, d: int): int {
        return m * 100 + d;
    }

    function pick(list: var, date: date): var {
        if (!list || list.length === 0)
            return null;
        const k = key(date.getMonth() + 1, date.getDate());
        let best = null, bestKey = -1, last = null, lastKey = -1;
        for (const e of list) {
            const ek = key(e.start[0], e.start[1]);
            if (ek <= k && ek > bestKey) {
                best = e;
                bestKey = ek;
            }
            if (ek > lastKey) {
                last = e;
                lastKey = ek;
            }
        }
        return best ?? last;   // early January belongs to the last entry of the previous year
    }

    // ── sun and moon (local calculation, no network) ──────────────────────────────────────────
    property date sunrise: new Date(NaN)
    property date sunset: new Date(NaN)
    readonly property string sunriseText: isNaN(sunrise.getTime()) ? "—" : Qt.formatTime(sunrise, "HH:mm")
    readonly property string sunsetText: isNaN(sunset.getTime()) ? "—" : Qt.formatTime(sunset, "HH:mm")
    property real moonAge: 0              // days since new moon (0–29.53)
    readonly property int moonIndex: Math.floor(((moonAge / 29.530588853) * 8) + 0.5) % 8
    readonly property var moon: Glossary.g.moonPhases ? Glossary.g.moonPhases[moonIndex] : { kanji: "", es: "" }
    // the current kō started at ko.start and the next one starts ~5 days later
    property int koDaysLeft: 0

    // Standard sunrise equation (≈1 min accuracy): Julian days, solar mean anomaly, equation of centre,
    // ecliptic longitude, declination, hour angle with −0.833° for refraction and the solar disc.
    function sunTimes(day: date, lat: real, lon: real): var {
        const rad = Math.PI / 180;
        const J = day.getTime() / 86400000 + 2440587.5;
        const n = Math.ceil(J - 2451545.0 + 0.0008);
        const Js = n - lon / 360;
        const M = (357.5291 + 0.98560028 * Js) % 360;
        const C = 1.9148 * Math.sin(M * rad) + 0.02 * Math.sin(2 * M * rad) + 0.0003 * Math.sin(3 * M * rad);
        const L = (M + C + 180 + 102.9372) % 360;
        const Jt = 2451545.0 + Js + 0.0053 * Math.sin(M * rad) - 0.0069 * Math.sin(2 * L * rad);
        const d = Math.asin(Math.sin(L * rad) * Math.sin(23.4397 * rad));
        const cw = (Math.sin(-0.833 * rad) - Math.sin(lat * rad) * Math.sin(d)) / (Math.cos(lat * rad) * Math.cos(d));
        if (cw < -1 || cw > 1)
            return { rise: new Date(NaN), set: new Date(NaN) };
        const w = Math.acos(cw) / rad;
        const toDate = jd => new Date((jd - 2440587.5) * 86400000);
        return { rise: toDate(Jt - w / 360), set: toDate(Jt + w / 360) };
    }

    function update(): void {
        const now = Time.now;
        ko = pick(table.ko, now) ?? ko;
        sekki = pick(table.sekki, now) ?? sekki;
        const st = sunTimes(now, Settings.data.weather.lat, Settings.data.weather.lon);
        sunrise = st.rise;
        sunset = st.set;
        const J = now.getTime() / 86400000 + 2440587.5;
        moonAge = ((J - 2451550.1) % 29.530588853 + 29.530588853) % 29.530588853;
        // days left in this kō: distance to the next entry's start date
        const list = (table.ko ?? []).slice().sort((a, b) => key(a.start[0], a.start[1]) - key(b.start[0], b.start[1]));
        const i = list.indexOf(ko);
        const next = list[(i + 1) % Math.max(1, list.length)];
        if (next) {
            let nd = new Date(now.getFullYear(), next.start[0] - 1, next.start[1]);
            if (nd < now)
                nd = new Date(now.getFullYear() + 1, next.start[0] - 1, next.start[1]);
            koDaysLeft = Math.max(0, Math.ceil((nd - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000));
        }
    }

    Connections {
        target: Time
        function onDayChanged() { root.update(); }
    }
    // the place changed (Settings → weather): recompute sun times
    readonly property string placeKey: Settings.data.weather.lat + "," + Settings.data.weather.lon
    onPlaceKeyChanged: update()

    FileView {
        path: Paths.asset("data/kisetsu-72.json")
        onLoaded: {
            try {
                root.table = JSON.parse(text());
                root.update();
            } catch (e) {
                console.warn("Kisetsu: kisetsu-72.json no válido:", e);
            }
        }
    }
}
