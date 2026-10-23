import QtQuick
import qs.config

ColorAnimation {
    property int ms: Motion.fast
    duration: Motion.d(ms)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standard
}
