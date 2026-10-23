import QtQuick
import qs.config

// The default animation: standard curve, duration from Motion (0 when motion is off).
NumberAnimation {
    property int ms: Motion.base
    duration: Motion.d(ms)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standard
}
