import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Section label (mock.css .sect): 11/600, tracking .09em, uppercase, textDim; 22 px above, 10 below.
OText {
    property real topGap: 22
    Layout.fillWidth: true
    // the page's ColumnLayout adds 4 px between items: subtracted on both sides (visual QA, fases 16–17: +4 above)
    Layout.topMargin: topGap - 4
    Layout.bottomMargin: 10 - 4
    size: Theme.font.caption - 0.5
    // mock.css .sect: font 600 11px/1 → an 11 px line box, not the font's natural one (~2 px taller)
    lineHeightMode: Text.FixedHeight
    lineHeight: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 11 * 0.09
    font.capitalization: Font.AllUppercase
    color: Theme.colors.textDim
}
