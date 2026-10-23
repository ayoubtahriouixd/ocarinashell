import QtQuick
import qs.config
import qs.components

// SRow with a drop-down bound to a settings path. options: [{ id, label, sub? }].
SRow {
    id: root
    property string key
    property var options: []
    property real menuWidth: 0
    signal changed(var v)
    Dropdown {
        options: root.options
        current: Settings.get(root.key, null)
        label: root.title
        menuWidth: root.menuWidth > 0 ? root.menuWidth : Math.max(width, 180)
        onPicked: id => {
            Settings.set(root.key, id);
            root.changed(id);
        }
    }
}
