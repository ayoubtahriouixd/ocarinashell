pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// One settings page: header (kanji 30 accent in `display` + title 26/600, mock.css .ph), subtitle, optional item on
// the right of the header (`headerRight`), «Restablecer sección» for the settings paths it owns, then its content.
ColumnLayout {
    id: root
    property string subtitle: ""
    property var resetPaths: []            // e.g. ["appearance"]; empty = no reset button
    property Component headerRight: null
    property bool fillsView: false         // the page scrolls by itself (Fondos): the outer Flickable stays still
    signal resetDone
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: -6                  // measured against mockup 07: Shippori's line box sits the row 6 px low
        Layout.bottomMargin: 2 - 8            // and the subtitle 8 px further (.ph margin-bottom 6, line-height 1)
        spacing: 14
        Kanji {
            text: Settei.pageInfo.kanji
            size: 30
            lineHeightMode: Text.FixedHeight
            lineHeight: 30
            color: Theme.colors.accent
            Layout.alignment: Qt.AlignBaseline
        }
        OText {
            text: Settei.pageInfo.es
            lineHeightMode: Text.FixedHeight
            lineHeight: 30
            size: Theme.font.h1
            font.weight: Font.DemiBold
            font.letterSpacing: -0.26
            Layout.alignment: Qt.AlignBaseline
        }
        Item { Layout.fillWidth: true }
        Loader {
            active: root.headerRight !== null
            sourceComponent: root.headerRight
            // a chip on the title's baseline (mockup 10: «Mamori activo»); buttons keep the vertical centre
            Layout.alignment: item && item.baselineOffset > 0 ? Qt.AlignBaseline : Qt.AlignVCenter
            baselineOffset: item ? item.baselineOffset : 0
        }
        OButton {
            id: resetBtn
            visible: root.resetPaths.length > 0
            Layout.alignment: Qt.AlignVCenter
            ghost: true
            icon: confirm ? "warning" : "restart_alt"
            text: confirm ? "¿Seguro? Pulsa otra vez" : "Restablecer sección"
            property bool confirm: false
            onClicked: {
                if (!confirm) {
                    confirm = true;
                    disarm.restart();
                    return;
                }
                confirm = false;
                for (const p of root.resetPaths)
                    Settings.reset(p);
                root.resetDone();
                Osd.show("info", 0, "Sección restablecida", "restart_alt");
            }
            Timer {
                id: disarm
                interval: 4000
                onTriggered: resetBtn.confirm = false
            }
        }
    }
    OText {
        visible: root.subtitle !== ""
        Layout.fillWidth: true
        Layout.bottomMargin: 22 - 4 - 22      // .sub margin 22 minus the section's own 22 top gap
        text: root.subtitle
        size: Theme.font.body
        color: Theme.colors.textMuted
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }
}
