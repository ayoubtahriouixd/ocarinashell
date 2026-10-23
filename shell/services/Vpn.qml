pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// VPN / WireGuard connections from NetworkManager (nmcli). Read when Engawa opens (no polling); the tile only exists
// if at least one VPN connection is configured.
Singleton {
    id: root

    property var names: []
    property string active: ""
    readonly property bool available: names.length > 0

    function refresh(): void {
        if (!list.running)
            list.running = true;
    }
    function toggle(): void {
        if (active !== "")
            run(["nmcli", "connection", "down", "id", active]);
        else if (names.length > 0)
            run(["nmcli", "connection", "up", "id", names[0]]);
    }
    function up(name: string): void {
        run(["nmcli", "connection", "up", "id", name]);
    }
    function run(cmd: list<string>): void {
        act.command = cmd;
        act.running = true;
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "TYPE,ACTIVE,NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = [];
                let a = "";
                for (const line of text.split("\n")) {
                    // TYPE:ACTIVE:NAME — the name is last and may contain escaped colons ("\:")
                    const i = line.indexOf(":"), j = line.indexOf(":", i + 1);
                    if (i < 0 || j < 0)
                        continue;
                    const type = line.slice(0, i), active = line.slice(i + 1, j);
                    const name = line.slice(j + 1).replace(/\\:/g, ":");
                    if (!/vpn|wireguard/.test(type))
                        continue;
                    n.push(name);
                    if (active === "yes")
                        a = name;
                }
                root.names = n;
                root.active = a;
            }
        }
    }
    Process {
        id: act
        onExited: root.refresh()
    }
    Component.onCompleted: refresh()
}
