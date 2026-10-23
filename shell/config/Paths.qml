pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Filesystem locations shared by the whole shell (docs/01-ARQUITECTURA §3). Our own XDG layout, not Quickshell's
// per-shell dirs: the CLI, the theme engine and Mamori read the same files.
Singleton {
    readonly property string version: "2.0.0"     // OcarinaShell (shell ipc version, Settei → Acerca de)
    readonly property string home: Quickshell.env("HOME") ?? ""
    // XDG variables: an empty value counts as unset (as `${VAR:-…}` in the bin/ helpers)
    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string config: xdgConfig + "/ocarinashell"
    readonly property string niri: xdgConfig + "/niri"
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/ocarinashell"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/ocarinashell"
    readonly property string data: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/ocarinashell"
    readonly property string runtime: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ocarinashell"     // RAM
    // shell/ is linked as ~/.config/quickshell/ocarina → resolve the repo through the link target's sibling assets
    readonly property string shell: Quickshell.shellDir.replace(/\/$/, "")
    readonly property string repo: Quickshell.env("OCARINA_REPO") ?? home + "/ocarinashell"
    readonly property string assets: repo + "/assets"
    readonly property string bin: repo + "/bin"

    readonly property string settings: config + "/settings.json"
    readonly property string theme: state + "/theme.json"
    readonly property string brightness: state + "/brightness.json"
    readonly property string wallpapers: data + "/wallpapers"

    function asset(rel: string): string {
        return assets + "/" + rel;
    }
    function url(path: string): string {
        if (!path.startsWith("/"))
            return path;
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
}
