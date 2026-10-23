import QtQuick
import qs.config

// The red torii drawn with plain rectangles (mockup 04 field icon, 30 × 26): kasagi (top beam, slightly arched by
// two overlapping bars), nuki (tie beam), two pillars and the gakuzuka strut.
Item {
    implicitWidth: 30
    implicitHeight: 26
    readonly property color c: Theme.colors.accent
    Rectangle { x: 0.5; y: 2; width: 29; height: 3.4; radius: 1.7; color: parent.c }
    Rectangle { x: 2; y: 4.4; width: 26; height: 2.4; radius: 1; color: parent.c }
    Rectangle { x: 4; y: 10; width: 22; height: 2.6; radius: 1; color: parent.c }
    Rectangle { x: 6.2; y: 6; width: 3; height: 19; radius: 1; color: parent.c }
    Rectangle { x: 20.8; y: 6; width: 3; height: 19; radius: 1; color: parent.c }
    Rectangle { x: 13.6; y: 6.6; width: 2.8; height: 4; color: parent.c }
}
