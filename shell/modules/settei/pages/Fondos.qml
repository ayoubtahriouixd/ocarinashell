pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 壁紙 Kabegami — wallpaper browser (Mod+Shift+W opens Settei here): grid of ~/Imágenes/Fondos + the included ones,
// large preview with ← →, apply with the ink transition, favourites, «tema desde este fondo» (matugen), optional
// rotation (AC only) or 季 by season (tags 春夏秋冬 with 1–4 in the preview; one per 七十二候 kō), and the Explorar
// tab (Wallhaven, SFW only, nothing is fetched until it is opened).
SetteiPage {
    id: page
    subtitle: "Tus fondos de ~/Imágenes/Fondos y los incluidos. Se aplican con la transición de tinta."
    resetPaths: []
    fillsView: true

    property string tab: "mine"          // mine | explore
    property string filter: "all"        // all | fav | season | builtin
    property int previewIndex: -1
    readonly property var list: Wallpapers.items.filter(i => filter === "all" || (filter === "fav" ? Wallpapers.isFavorite(i.path)
        : filter === "season" ? Wallpapers.seasonsOf(i.path).indexOf(Kisetsu.season) >= 0 : i.builtin))
    readonly property var seasons: Glossary.g.seasons ?? []
    readonly property string seasonKanji: seasons[Kisetsu.season]?.kanji ?? "季"
    function seasonText(p: string): string {
        return Wallpapers.seasonsOf(p).map(s => seasons[s]?.kanji ?? "").join("");
    }
    readonly property var shown: tab === "mine" ? list : Wallpapers.wh
    function base(p: string): string {
        return p.split("/").pop().replace(/\.[^.]+$/, "");
    }
    Component.onCompleted: Wallpapers.ensure()

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.bottomMargin: 8
        spacing: 12
        Segmented {
            Layout.preferredWidth: 320
            visible: Wallpapers.exploreOn
            options: [{ id: "mine", kanji: "壁", label: "Mis fondos" }, { id: "explore", kanji: "探", label: "Explorar" }]
            current: page.tab
            onPicked: id => {
                page.tab = id;
                page.previewIndex = -1;
                if (id === "explore" && Wallpapers.wh.length === 0 && !Wallpapers.whBusy)
                    Wallpapers.search("", 1);
            }
        }
        Segmented {
            visible: page.tab === "mine"
            Layout.preferredWidth: 430
            options: [{ id: "all", label: "Todos · " + Wallpapers.items.length }, { id: "fav", label: "Favoritos · " + Wallpapers.favorites.length },
                      { id: "season", kanji: page.seasonKanji, label: "Estación · " + Wallpapers.seasonPool(Kisetsu.season).length },
                      { id: "builtin", label: "Incluidos" }]
            current: page.filter
            onPicked: id => page.filter = id
        }
        TextInput_ {
            id: query
            visible: page.tab === "explore"
            Layout.fillWidth: true
            placeholder: "Buscar en Wallhaven (inglés: «sakura», «mountain», «tokyo night»)…"
            onAccepted: Wallpapers.search(text, 1)
        }
        Item { visible: page.tab === "mine"; Layout.fillWidth: true }
        OButton {
            visible: page.tab === "mine"
            ghost: true
            icon: "folder_open"
            text: "Carpeta"
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", Wallpapers.userDir])
        }
        OButton {
            visible: page.tab === "explore"
            primary: true
            icon: "search"
            text: "Buscar"
            onClicked: Wallpapers.search(query.text, 1)
        }
    }

    // grid
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        GridView {
            id: grid
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            clip: true
            model: page.shown
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.round((cellWidth - 12) * 10 / 16 + 12)
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400
            reuseItems: true
            keyNavigationEnabled: true
            activeFocusOnTab: true
            highlightFollowsCurrentItem: false
            Keys.onReturnPressed: if (currentIndex >= 0) page.previewIndex = currentIndex
            Keys.onSpacePressed: if (currentIndex >= 0) page.previewIndex = currentIndex
            onAtYEndChanged: if (atYEnd && page.tab === "explore" && Wallpapers.wh.length > 0 && !Wallpapers.whBusy)
                Wallpapers.search(Wallpapers.whQuery, Wallpapers.whPage + 1)
            delegate: WallThumb {
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                source: page.tab === "mine" ? Paths.url(modelData.thumb) : modelData.thumb
                name: page.tab === "mine" ? page.base(modelData.path) : modelData.res
                current: page.tab === "mine" && modelData.path === Wallpapers.current
                focused: grid.activeFocus && grid.currentIndex === index
                favorite: page.tab === "mine" && Wallpapers.isFavorite(modelData.path)
                seasonText: page.tab === "mine" ? page.seasonText(modelData.path) : ""
                showFavorite: page.tab === "mine"
                busy: page.tab === "explore" && !!Wallpapers.downloading[modelData.id]
                onOpen: page.previewIndex = index
                onFavoriteToggled: Wallpapers.toggleFavorite(modelData.path)
            }
        }
        ColumnLayout {
            anchors.centerIn: parent
            visible: grid.count === 0
            spacing: 8
            Kanji { Layout.alignment: Qt.AlignHCenter; text: page.tab === "mine" ? "壁" : "探"; size: 54; opacity: 0.25 }
            OText {
                Layout.alignment: Qt.AlignHCenter
                text: page.tab === "explore" ? (Wallpapers.whBusy ? "Buscando…" : Wallpapers.whError || "Sin resultados")
                    : Wallpapers.indexing ? "Preparando miniaturas…"
                    : page.filter === "fav" ? "Marca fondos con ♥ para verlos aquí" : "Copia imágenes en ~/Imágenes/Fondos"
                color: Theme.colors.textMuted
            }
        }
    }

    // bottom bar: current wallpaper actions + rotation
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 10
        OText {
            Layout.fillWidth: true
            text: page.tab === "explore" ? "Wallhaven · solo contenido apto (SFW) · se guarda en ~/Imágenes/Fondos/wallhaven"
                : "Actual: " + page.base(Wallpapers.current) + (Settings.data.wallpaper.path === "" ? " (el del tema)" : "")
            elide: Text.ElideMiddle
            size: 12
            color: Theme.colors.textDim
        }
        OButton {
            visible: page.tab === "mine" && Settings.data.wallpaper.path !== ""
            ghost: true
            icon: "undo"
            text: "Usar el del tema"
            onClicked: Settings.set("wallpaper.path", "")
        }
        OText { visible: page.tab === "mine"; text: "Explorar (Wallhaven)"; size: 12.5; color: Theme.colors.textMuted }
        Switch_ {
            visible: page.tab === "mine"
            checked: Settings.data.wallhaven.enabled
            label: "Pestaña Explorar con Wallhaven"
            onToggled: Settings.set("wallhaven.enabled", !checked)
        }
        OText { visible: page.tab === "mine"; text: "Rotar"; size: 12.5; color: Theme.colors.textMuted; leftPadding: 8 }
        Dropdown {
            visible: page.tab === "mine"
            label: "Rotación de fondos"
            options: [{ id: 0, label: "Nunca" }, { id: 15, label: "Cada 15 min" }, { id: 30, label: "Cada 30 min" },
                      { id: 60, label: "Cada hora" }, { id: 240, label: "Cada 4 h" }, { id: 1440, label: "Cada día" },
                      { id: -1, label: "Con el 七十二候" }]
            current: Settings.data.wallpaper.rotate
            menuWidth: 200
            onPicked: id => Settings.set("wallpaper.rotate", id)
        }
        Chip {
            visible: page.tab === "mine" && Settings.data.wallpaper.rotate !== 0
            readonly property int pool: Wallpapers.seasonPool(Kisetsu.season).length
            kanji: Wallpapers.seasonal ? page.seasonKanji : ""
            text: Wallpapers.seasonal ? (pool > 0 ? pool + (pool === 1 ? " fondo" : " fondos") + " · cambia cada kō"
                                                  : "etiqueta fondos de " + (page.seasons[Kisetsu.season]?.es ?? "esta estación"))
                : Power.onBattery ? "en pausa con batería" : Wallpapers.favorites.length >= 2 ? "entre favoritos" : "entre todos"
            tone: Wallpapers.seasonal ? (pool > 0 ? "ok" : "red") : Power.onBattery ? "" : "ok"
        }
    }

    // large preview over the grid
    Rectangle {
        id: preview
        parent: page.parent
        visible: page.previewIndex >= 0 && page.previewIndex < page.shown.length
        anchors.fill: parent
        anchors.margins: -8
        z: 50
        radius: 16
        color: Theme.alpha(Theme.colors.surface0, 0.97)
        focus: visible
        onVisibleChanged: if (visible) forceActiveFocus()
        readonly property var it: visible ? page.shown[page.previewIndex] : null
        readonly property bool mine: page.tab === "mine"
        function step(d: int): void {
            page.previewIndex = (page.previewIndex + d + page.shown.length) % page.shown.length;
        }
        function applyIt(): void {
            if (mine)
                Wallpapers.apply(it.path);
            else
                Wallpapers.download(it, true);
        }
        Keys.onLeftPressed: step(-1)
        Keys.onRightPressed: step(1)
        Keys.onEscapePressed: page.previewIndex = -1
        Keys.onReturnPressed: applyIt()
        Keys.onPressed: e => {
            if (!mine)
                return;
            if (e.key === Qt.Key_F) {
                Wallpapers.toggleFavorite(it.path);
                e.accepted = true;
            } else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) {      // 1–4: 春 夏 秋 冬
                Wallpapers.toggleSeason(it.path, e.key - Qt.Key_1);
                e.accepted = true;
            }
        }
        MouseArea { anchors.fill: parent; onWheel: w => preview.step(w.angleDelta.y > 0 ? -1 : 1) }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                IconButton { icon: "chevron_left"; label: "Anterior"; onClicked: preview.step(-1) }
                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Theme.colors.surface2
                    Image {
                        id: big
                        anchors.fill: parent
                        source: !preview.it ? "" : preview.mine ? Paths.url(preview.it.path) : preview.it.thumb
                        sourceSize.width: 1800
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Image {
                        anchors.fill: parent
                        visible: big.status !== Image.Ready
                        source: !preview.it ? "" : preview.mine ? Paths.url(preview.it.thumb) : preview.it.thumb
                        fillMode: Image.PreserveAspectFit
                    }
                }
                IconButton { icon: "chevron_right"; label: "Siguiente"; onClicked: preview.step(1) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                IconButton { icon: "close"; label: "Cerrar"; onClicked: page.previewIndex = -1 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    OText { text: !preview.it ? "" : preview.mine ? page.base(preview.it.path) : "Wallhaven " + preview.it.id; font.weight: Font.DemiBold }
                    OText {
                        text: (page.previewIndex + 1) + " / " + page.shown.length + (big.status === Image.Ready && big.implicitWidth > 0 ? "" : "")
                            + (preview.it && !preview.mine ? " · " + preview.it.res : "") + " · ← → para pasar, Intro para aplicar" + (preview.mine ? ", 1–4 estación" : "")
                        size: 12
                        color: Theme.colors.textMuted
                        tabular: true
                    }
                }
                // 季 tags for the seasonal rotation (keys 1–4)
                Repeater {
                    model: preview.mine ? page.seasons : []
                    delegate: Rectangle {
                        id: tag
                        required property var modelData
                        required property int index
                        readonly property bool on: !!preview.it && Wallpapers.seasonsOf(preview.it.path).indexOf(index) >= 0
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 10
                        color: on ? Theme.colors.accentSoft : tagArea.containsMouse ? Theme.colors.surface3 : Theme.colors.surface2
                        border.width: 1
                        border.color: on ? Theme.colors.accent : Theme.colors.outline
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: modelData.es + " (" + (index + 1) + ")"
                        Accessible.checked: on
                        Behavior on color { CAnim {} }
                        Kanji {
                            anchors.centerIn: parent
                            text: tag.modelData.kanji
                            size: 14
                            color: tag.on ? Theme.colors.accent : Theme.colors.textMuted
                        }
                        MouseArea {
                            id: tagArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.toggleSeason(preview.it.path, tag.index)
                        }
                    }
                }
                OButton {
                    visible: preview.mine
                    ghost: true
                    icon: "favorite"
                    text: preview.it && Wallpapers.isFavorite(preview.it.path) ? "Quitar de favoritos" : "Favorito"
                    onClicked: Wallpapers.toggleFavorite(preview.it.path)
                }
                OButton {
                    visible: preview.mine
                    icon: "palette"
                    text: "Tema desde este fondo"
                    onClicked: Wallpapers.themeFrom(preview.it.path)
                }
                OButton {
                    visible: !preview.mine
                    icon: "download"
                    text: "Descargar"
                    onClicked: Wallpapers.download(preview.it, false)
                }
                OButton {
                    primary: true
                    icon: preview.mine ? "wallpaper" : "download_done"
                    text: preview.mine ? (preview.it && preview.it.path === Wallpapers.current ? "Aplicado" : "Aplicar")
                        : (preview.it && Wallpapers.downloading[preview.it.id] ? "Descargando…" : "Descargar y aplicar")
                    onClicked: preview.applyIt()
                }
            }
        }
    }
}
