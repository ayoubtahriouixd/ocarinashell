import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Sensitive module (Quickshell.Services.UPower) isolated in its own file (docs/06 capa 3.1): if an update renames a
// type, only this file fails to compile and Power reports «no disponible»; the singleton itself imports nothing risky.
QtObject {
    id: backend

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool ready: battery?.ready ?? false
    readonly property bool isLaptopBattery: battery?.isLaptopBattery ?? false
    readonly property real percentage: ready ? battery.percentage : 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
    readonly property bool full: battery?.state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: battery?.state === UPowerDeviceState.Discharging
    readonly property bool onBattery: UPower.onBattery
    readonly property real timeToEmpty: battery?.timeToEmpty ?? 0
    readonly property real timeToFull: battery?.timeToFull ?? 0
    readonly property real changeRate: battery?.changeRate ?? 0
    readonly property real energy: battery?.energy ?? 0
    readonly property string nativePath: battery?.nativePath ?? ""

    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
        : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    function setProfile(id: string): void {
        PowerProfiles.profile = id === "power-saver" ? PowerProfile.PowerSaver
            : id === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
