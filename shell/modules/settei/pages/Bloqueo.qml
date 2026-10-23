pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.settei

// 鍵 Bloqueo e inactividad: idle times on AC and battery, fingerprint, privacy, what the lock screen shows.
SetteiPage {
    id: page
    subtitle: "Cuándo se atenúa, se bloquea y se apaga la pantalla, y qué se ve con el equipo bloqueado."
    resetPaths: ["idle", "lock"]
    headerRight: Component {
        OButton {
            icon: "visibility"
            text: "Probar (falso, sale con Esc)"
            onClicked: Lock.startTest()
        }
    }

    function opts(list: var): var {
        return list.map(m => ({ id: m, label: m === 0 ? "Nunca" : m < 1 ? Math.round(m * 60) + " s" : m + " min" }));
    }
    readonly property var dimOpts: opts([0, 1, 2, 3, 4, 5, 10])
    readonly property var lockOpts: opts([0, 1, 2, 3, 5, 10, 15, 30])
    readonly property var offOpts: opts([0, 1, 2, 3, 4, 6, 10, 15, 30])
    readonly property var sleepOpts: opts([0, 5, 10, 15, 20, 30, 60])

    SectionTitle { text: "Inactividad · con cargador" }
    Card {
        DropRow { title: "Atenuar la pantalla"; sub: "Al 30 %; vuelve en cuanto tocas algo"; key: "idle.ac.dim"; options: page.dimOpts }
        DropRow { title: "Bloquear"; key: "idle.ac.lock"; options: page.lockOpts }
        DropRow { title: "Apagar la pantalla"; key: "idle.ac.screenOff"; options: page.offOpts }
        DropRow { title: "Suspender"; key: "idle.ac.suspend"; options: page.sleepOpts }
    }
    SectionTitle { text: "Inactividad · con batería" }
    Card {
        DropRow { title: "Atenuar la pantalla"; sub: "Con batería, antes"; key: "idle.battery.dim"; options: page.dimOpts }
        DropRow { title: "Bloquear"; key: "idle.battery.lock"; options: page.lockOpts }
        DropRow { title: "Apagar la pantalla"; key: "idle.battery.screenOff"; options: page.offOpts }
        DropRow { title: "Suspender"; key: "idle.battery.suspend"; options: page.sleepOpts }
    }
    SectionTitle { text: "Pantalla de bloqueo" }
    Card {
        ToggleRow {
            title: "Huella"
            sub: Lock.fingerprint || Settings.data.lock.fingerprint ? "Desbloquear con el lector (si hay dedos registrados con fprintd-enroll)" : "Solo contraseña"
            key: "lock.fingerprint"
        }
        ToggleRow { title: "Reproductor en el bloqueo"; sub: "Mini reproductor abajo a la izquierda (sin carátula fuera de la pantalla principal)"; key: "lock.showMedia" }
        ToggleRow { title: "Fondo difuminado"; sub: "Tu fondo de pantalla, difuminado, detrás del reloj"; key: "lock.blurWallpaper" }
        ToggleRow { title: "Bloqueo a la deriva"; sub: "保護 Hogo: reloj y texto se mueven despacio (cuida el OLED)"; key: "oled.lockDrift" }
    }
}
