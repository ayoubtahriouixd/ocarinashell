pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// What failed to load and why (docs/06 capa 3). ModuleLoader and services report here; Settei → Acerca de →
// Diagnóstico and `ocarina doctor` read it. Nothing here ever throws.
Singleton {
    id: root

    property var failures: ({})        // name → error string
    readonly property int count: Object.keys(failures).length

    function fail(name: string, error: string): void {
        const f = Object.assign({}, failures);
        f[name] = error;
        failures = f;
        console.warn("Health:", name, "no disponible:", error);
    }
    function ok(name: string): void {
        if (!(name in failures))
            return;
        const f = Object.assign({}, failures);
        delete f[name];
        failures = f;
    }
    function report(): string {
        return JSON.stringify(failures);
    }
}
