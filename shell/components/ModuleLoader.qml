pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// Loads one module file in isolation (docs/06 capa 3.1). If the file (or a Quickshell module it imports) fails to
// compile after an update, only this module is missing: the error goes to Health and the rest of the shell lives.
// Works for windows too (PanelWindow is not an Item, so Loader cannot host it). `fallback` is tried next — e.g. the
// bar without compositor blur. Properties in `props` are set at creation (a window gets its screen before mapping).
Scope {
    id: root

    required property string name
    required property url source
    property url fallback: ""
    property var props: ({})
    property bool active: true

    // Diagnostics: OCARINA_DISABLE="Obi,Shima" skips modules whose name starts with one of the entries.
    readonly property bool disabledByEnv: (Quickshell.env("OCARINA_DISABLE") ?? "").split(",")
        .some(n => n !== "" && name.startsWith(n))

    property QtObject item: null
    readonly property bool available: item !== null
    property string error: ""

    function unload(): void {
        if (item) {
            item.destroy();
            item = null;
        }
    }

    function tryLoad(url: url): bool {
        const c = Qt.createComponent(url, Component.PreferSynchronous);
        if (c.status !== Component.Ready) {
            error = c.errorString();
            return false;
        }
        const o = c.createObject(root, props);
        if (!o) {
            error = "createObject devolvió null";
            return false;
        }
        item = o;
        return true;
    }

    function load(): void {
        unload();
        error = "";
        if (!active || disabledByEnv)
            return;
        if (tryLoad(source)) {
            Health.ok(name);
            return;
        }
        const first = error;
        if (fallback.toString() !== "" && tryLoad(fallback)) {
            Health.fail(name + " (principal)", first);
            return;
        }
        Health.fail(name, first);
    }

    // props are applied at creation and again whenever they change (e.g. the island moving to another screen)
    onPropsChanged: {
        if (!item)
            return;
        for (const k in props)
            if (k !== "screen" && item[k] !== props[k])
                item[k] = props[k];
    }
    property bool completed: false
    onActiveChanged: if (completed) load()
    Component.onCompleted: {
        completed = true;
        load();
    }
    Component.onDestruction: unload()
}
