import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Sensitive module (Quickshell.Services.Notifications) isolated in its own file (docs/06 capa 3.1). If it cannot load,
// nobody owns org.freedesktop.Notifications: the CLI's notify-send fallbacks stay silent and Health says why.
NotificationServer {
    required property QtObject owner

    keepOnReload: true
    actionsSupported: true
    actionIconsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: false
    imageSupported: true
    inlineReplySupported: true
    persistenceSupported: true
    onNotification: n => owner.add(n)
}
