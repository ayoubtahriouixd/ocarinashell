pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Weather from Open-Meteo (no key), every 30 min, cached on disk. Off in Shinobi and when disabled.
Singleton {
    id: root

    property real temperature: NaN
    property int code: -1
    property bool isDay: true
    property double fetched: 0       // epoch ms of the last successful fetch
    property var daily: []           // [{ date, code, max, min }] × 3
    property var hourly: []          // [{ iso, time "HH", code, temp }] × 8 from the current hour (広場 Hiroba)
    // the hours still ahead (the list can be up to 30 min old): what 広場 shows
    readonly property var hoursAhead: {
        const h = Time.minute;      // re-evaluated on the minute
        const cut = new Date(h.getFullYear(), h.getMonth(), h.getDate(), h.getHours()).getTime();
        return hourly.filter(x => !x.iso || new Date(x.iso).getTime() >= cut);
    }
    property var today: ({})         // { max, min }
    property string error: ""
    readonly property bool available: !isNaN(temperature)
    // only while something shows it (bar now, Koyomi from phase 4): no requests, no timer otherwise
    readonly property bool enabled: Settings.data.weather.enabled && Settings.data.bar.showWeather && !Modes.quiet
    property bool cacheRead: false

    // on demand (Koyomi opening): only if the cache is older than 30 min, never in Shinobi
    function refresh(): void {
        if (Settings.data.weather.enabled && !Modes.quiet
                && (Date.now() - fetched > 30 * 60 * 1000 || daily.length === 0 || hourly.length === 0))
            fetchNow();
    }
    function info(c: int): var {
        return (Glossary.g.weatherWmo ?? {})[String(c)] ?? { kanji: "", es: "", icon: "cloud" };
    }
    function fetch(): void {
        if (!enabled)
            return;
        fetchNow();
    }
    function fetchNow(): void {
        const w = Settings.data.weather;
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + w.lat + "&longitude=" + w.lon
            + "&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&hourly=temperature_2m,weather_code&forecast_hours=9&forecast_days=4&timezone=auto";
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status !== 200) {
                root.error = "HTTP " + x.status;
                return;
            }
            try {
                const c = JSON.parse(x.responseText).current;
                root.temperature = c.temperature_2m;
                root.code = c.weather_code;
                root.isDay = c.is_day === 1;
                const dd = JSON.parse(x.responseText).daily ?? {};
                const out = [];
                for (let i = 1; i < (dd.time ?? []).length && out.length < 3; i++)
                    out.push({ date: dd.time[i], code: dd.weather_code[i], max: dd.temperature_2m_max[i],
                               min: dd.temperature_2m_min[i] });
                root.daily = out;
                root.today = (dd.time ?? []).length ? { max: dd.temperature_2m_max[0], min: dd.temperature_2m_min[0] } : {};
                const hh = JSON.parse(x.responseText).hourly ?? {};
                const hours = [];
                for (let i = 0; i < (hh.time ?? []).length && hours.length < 8; i++)
                    hours.push({ iso: String(hh.time[i]), time: String(hh.time[i]).slice(11, 13), code: hh.weather_code[i],
                                 temp: hh.temperature_2m[i] });
                root.hourly = hours;
                root.fetched = Date.now();
                root.error = "";
                cache.setText(JSON.stringify({ temperature: root.temperature, code: root.code, isDay: root.isDay,
                                               daily: root.daily, hourly: root.hourly, today: root.today,
                                               fetched: root.fetched }) + "\n");
            } catch (e) {
                root.error = String(e);
            }
        };
        x.open("GET", url);
        x.send();
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: root.enabled && root.cacheRead
        triggeredOnStart: Date.now() - root.fetched > 30 * 60 * 1000
        onTriggered: root.fetch()
    }

    FileView {
        id: cache
        atomicWrites: true
        path: Paths.cache + "/weather.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.temperature = d.temperature;
                root.code = d.code;
                root.isDay = d.isDay;
                root.fetched = d.fetched;
                root.daily = d.daily ?? [];
                root.hourly = d.hourly ?? [];
                root.today = d.today ?? {};
            } catch (e) {}
            root.cacheRead = true;
        }
        onLoadFailed: root.cacheRead = true
    }
}
