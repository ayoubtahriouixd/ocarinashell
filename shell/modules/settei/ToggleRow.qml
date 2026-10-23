import QtQuick
import qs.config
import qs.components

// SRow with a switch bound to a settings path ("appearance.blur"). `changed(v)` after the write, for side effects.
SRow {
    id: root
    property string key
    property bool invert: false
    readonly property bool value: Boolean(Settings.get(key, false)) !== invert
    signal changed(bool v)
    Switch_ {
        checked: root.value
        label: root.title
        onToggled: {
            const next = !root.value;
            Settings.set(root.key, root.invert ? !next : next);
            root.changed(next);
        }
    }
}
