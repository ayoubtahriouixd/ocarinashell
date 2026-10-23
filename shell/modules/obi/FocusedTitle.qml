pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Icon of the focused app (from its .desktop entry) + window title, 13 px muted, max 360 px.
RowLayout {
    id: root
    spacing: 7
    Layout.alignment: Qt.AlignVCenter

    readonly property var win: Niri.focusedWindow
    readonly property string title: win?.title ?? ""
    readonly property bool prod: Honban.isProdTitle(title)
    // strings only notify when they change: the desktop-entry lookup runs per app, not per title update
    readonly property string appId: win?.app_id ?? ""
    // 船 Fune: a RemoteApp window says it comes from Windows (mockup 09: «… — Documentos (Windows)»)
    readonly property bool fune: (appId.startsWith("fune-") && !appId.startsWith("fune-web-")) || appId.startsWith("steam_app_fune")
    readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
    // monochrome symbol in textMuted (mockup: no third colour in the 紅白 bar); app icon only as a dimmed fallback
    readonly property string symbol: {
        const id = appId.toLowerCase(), t = (win?.title ?? "").toLowerCase();
        if (root.fune) return "desktop_windows";                         // 船 Fune: monochrome, like the rest of the bar
        if (t === "ajustes de ocarinashell") return "settings";          // Settei (a Quickshell window)
        if (/nvim|vim|code|zed|helix/.test(t) || /code|zed|jetbrains/.test(id)) return "code";
        if (/ghostty|alacritty|kitty|foot|wezterm|terminal/.test(id)) return "terminal";
        if (/chrome|chromium|firefox|zen|brave|librewolf/.test(id)) return "public";
        if (/nautilus|files|thunar|dolphin/.test(id)) return "folder";
        if (/mpv|vlc|celluloid|spotify|music/.test(id)) return "music_note";
        if (/discord|telegram|signal|slack|whatsapp/.test(id)) return "forum";
        if (/settings|ocarina/.test(id)) return "tune";
        return "";
    }
    readonly property string iconPath: symbol === "" && entry?.icon ? Quickshell.iconPath(entry.icon, true) : ""

    IconImage {
        Layout.preferredWidth: 17
        Layout.preferredHeight: 17
        opacity: 0.7
        visible: root.iconPath !== ""
        source: root.iconPath
        implicitSize: 17
        asynchronous: true
    }
    OIcon {
        visible: root.win !== null && root.iconPath === ""
        icon: root.symbol || "web_asset"
        size: 17
        color: Theme.colors.textMuted
    }
    // 本番 Honban: a production SSH window (bin/ocarina-honban) gets its seal before the title
    Rectangle {
        visible: root.prod
        Layout.preferredHeight: 18
        Layout.preferredWidth: seal.implicitWidth + 10
        radius: Theme.radius.hanko - 3
        color: Theme.colors.accent         // the hanko colours (accent + its ink): legible at 11 px
        Kanji {
            id: seal
            anchors.centerIn: parent
            text: "本番"
            size: 11
            color: Theme.colors.accentInk
        }
        Accessible.role: Accessible.StaticText
        Accessible.name: "Producción"
    }
    OText {
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth   // hug the title: the «(Windows)» suffix follows it, never elided
        // leading spinners/status marks (Claude Code animates «◐ ◓ ✳» every second) are dropped: the text then stays
        // identical and the bar is not redrawn (fase 07 perf audit: ~23 wake-ups per title change)
        text: root.win ? ((root.win.title ?? "").replace(/^[\u25d0-\u25d3\u2733\u2736\u273b\u273d\u00b7\u2022\u2800-\u28ff\s]+/, "")
                                                .replace(root.fune ? /\s*\[Administra(tor|dor)\]$/ : /$^/, "")
                          || root.entry?.name || root.win.app_id || "") : ""
        color: Theme.colors.textMuted
        size: 13
    }
    OText {
        visible: root.fune
        Layout.leftMargin: -3                    // the row's spacing already reads as a space
        text: "(Windows)"
        color: Theme.colors.textMuted
        size: 13
    }
}
