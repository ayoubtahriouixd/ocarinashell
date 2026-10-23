import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// A card that hosts one of Engawa's detail pages (Wi-Fi, Bluetooth, Sonido) in isolation: if the Quickshell module
// behind it breaks after an update, only this card shows the error (docs/06 capa 3.1).
Card {
    id: root
    required property url source
    property string name: ""
    implicitHeight: Math.max(120, (loader.item ? loader.item.implicitHeight : 60) + 32)
    Loader {
        id: loader
        x: 16
        y: 16
        width: root.width - 32
        source: root.source
        onLoaded: item.embedded = true
        onStatusChanged: if (status === Loader.Error) Health.fail("Settei · " + root.name, "la página de Engawa no carga")
    }
    OText {
        visible: loader.status === Loader.Error
        x: 18
        y: 18
        text: root.name + " no está disponible ahora (mira «ocarina doctor»)"
        color: Theme.colors.textMuted
    }
}
