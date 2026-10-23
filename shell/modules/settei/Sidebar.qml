pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import "index.js" as SearchIndex

// Settei sidebar (mock.css .side): 262 px, surface1, wordmark, search (/), one entry per page with its kanji glyph.
// While searching, the list shows matching pages and settings; ↑/↓ + Enter or a click opens one.
Rectangle {
    id: root
    color: Theme.colors.surface1
    property alias searchField: input

    function norm(s: string): string {
        return (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }
    readonly property var results: {
        const q = norm(Settei.query).trim();
        if (q === "")
            return [];
        const words = q.split(/\s+/);
        const hit = h => words.every(w => h.indexOf(w) >= 0);
        const out = [];
        for (const p of Settei.pages)
            if (hit(norm(p.es + " " + (p.keys ?? "") + " " + p.kanji + " " + p.glyph)))
                out.push({ page: p.id, glyph: p.glyph, title: p.es, hint: "", row: "" });
        for (const e of SearchIndex.entries) {
            if (!hit(norm(e.t + " " + (e.s ?? "") + " " + (e.k ?? ""))))
                continue;
            const p = Settei.pages.find(x => x.id === e.p);
            if (p)
                out.push({ page: e.p, glyph: p.glyph, title: e.t, hint: p.es, row: e.t });
        }
        return out.slice(0, 18);
    }
    property int hi: 0
    onResultsChanged: hi = 0
    function activate(i: int): void {
        const r = results[i];
        if (!r)
            return;
        if (r.row !== "")
            Settei.goTo(r.page, r.row);
        else {
            Settei.query = "";
            Settei.go(r.page);
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.colors.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 20
        anchors.bottomMargin: 20
        anchors.leftMargin: 14
        anchors.rightMargin: 15
        spacing: 0

        RowLayout {
            Layout.leftMargin: 8
            Layout.topMargin: 2
            Layout.bottomMargin: 18
            spacing: 10
            Image {
                source: Paths.url(Paths.asset("logo/png/ocarinashell-icon-64.png"))
                sourceSize: Qt.size(60, 60)
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                smooth: true
                mipmap: true
            }
            Text {
                textFormat: Text.StyledText
                text: "Ocarina<font color=\"" + Theme.colors.accent + "\">Shell</font>"
                color: Theme.colors.text
                font.family: Theme.font.brand
                font.weight: Font.DemiBold
                font.pointSize: 17 * 0.75 * Theme.font.scale
                font.letterSpacing: -0.17
            }
        }

        Rectangle {
            id: search
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            implicitHeight: 38
            radius: 11
            color: Theme.colors.surface0
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? Theme.colors.accent : Theme.colors.outline
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 8
                spacing: 8
                OIcon {
                    icon: "search"
                    size: 18
                    color: Theme.colors.textDim
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextInput {
                        id: input
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.colors.text
                        selectionColor: Theme.colors.accentSoft
                        selectedTextColor: Theme.colors.text
                        font.family: Theme.font.ui
                        font.pointSize: 13 * 0.75 * Theme.font.scale
                        clip: true
                        text: Settei.query
                        onTextEdited: Settei.query = text
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "Buscar ajustes"
                        Keys.onDownPressed: root.hi = Math.min(root.results.length - 1, root.hi + 1)
                        Keys.onUpPressed: root.hi = Math.max(0, root.hi - 1)
                        Keys.onReturnPressed: root.activate(root.hi)
                        Keys.onEnterPressed: root.activate(root.hi)
                        Keys.onEscapePressed: e => {
                            if (text !== "") {
                                Settei.query = "";
                            } else {
                                input.focus = false;
                                e.accepted = false;      // the window closes on a second Esc
                            }
                        }
                    }
                    OText {
                        anchors.fill: parent
                        visible: input.text === ""
                        text: "Buscar ajustes…"
                        size: 13
                        color: Theme.colors.textDim
                    }
                }
                Kbd {
                    visible: input.text === ""
                    text: "/"
                }
                IconButton {
                    visible: input.text !== ""
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "close"
                    label: "Borrar búsqueda"
                    onClicked: Settei.query = ""
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.IBeamCursor
                onPressed: m => { input.forceActiveFocus(); m.accepted = false; }
            }
        }

        // pages (or search results)
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: navCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Column {
                id: navCol
                width: parent.width
                Repeater {
                    model: Settei.query === "" ? Settei.pages : []
                    delegate: NavItem {
                        required property var modelData
                        width: navCol.width
                        glyph: modelData.glyph
                        text: modelData.es
                        selected: Settei.page === modelData.id
                        later: Settei.later[modelData.id] !== undefined
                        // 守: what Mamori left for you to look at (mockup 07 shows the badge there)
                        badge: modelData.id === "mamori" ? Mamori.attention : 0
                        onActivated: Settei.go(modelData.id)
                    }
                }
                Repeater {
                    model: root.results
                    delegate: NavItem {
                        required property var modelData
                        required property int index
                        width: navCol.width
                        glyph: modelData.glyph
                        text: modelData.title
                        hint: modelData.hint
                        selected: index === root.hi
                        onActivated: root.activate(index)
                    }
                }
                OText {
                    visible: Settei.query !== "" && root.results.length === 0
                    width: navCol.width
                    leftPadding: 10
                    topPadding: 10
                    text: "Nada coincide con «" + Settei.query + "»"
                    size: 12.5
                    color: Theme.colors.textDim
                }
            }
        }
    }
}
