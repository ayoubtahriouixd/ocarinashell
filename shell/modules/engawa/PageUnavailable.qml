import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.modules.engawa

// Shown when a detail page fails to load (a Quickshell module changed after an update): never a blank panel.
ColumnLayout {
    id: root
    spacing: 10
    signal back
    PageHeader {
        Layout.fillWidth: true
        title: "No disponible"
        onBack: root.back()
    }
    OText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        maximumLineCount: 4
        text: "Esta página no se ha podido cargar tras una actualización. El resto de la shell funciona; 守 Mamori lo revisará (detalles: ocarina doctor)."
        color: Theme.colors.textMuted
        size: 12.5
    }
}
