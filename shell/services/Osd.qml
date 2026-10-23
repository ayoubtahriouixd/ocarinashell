pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// One-way bus from services to Shima: show("volume", 0.42, "Altavoces", "volume_up").
Singleton {
    id: root

    property string kind: ""
    property real value: 0
    property string label: ""
    property string icon: ""
    property int serial: 0           // increments on every show(): Shima restarts its hide timer

    function show(k: string, v: real, l: string, i: string): void {
        kind = k;
        value = v;
        label = l;
        icon = i;
        serial++;
    }
}
