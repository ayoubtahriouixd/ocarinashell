//@ pragma ShellId ocarina
//@ pragma Env QS_NO_RELOAD_POPUP=1
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
// Registered here so the modules can import themselves; importing compiles nothing until a type is used, so a
// broken module still fails alone inside its ModuleLoader.
import qs.modules.obi as ObiModule
import qs.modules.shima as ShimaModule
import qs.modules.engawa as EngawaModule
import qs.modules.fumi as FumiModule
import qs.modules.koyomi as KoyomiModule
import qs.modules.panels as PanelsModule
import qs.modules.torii as ToriiModule
import qs.modules.kura as KuraModule
import qs.modules.techo as TechoModule
import qs.modules.mihari as MihariModule
import qs.modules.mado as MadoModule
import qs.modules.cheatsheet as CheatsheetModule
import qs.modules.iro as IroModule
import qs.modules.kabegami as KabegamiModule
import qs.modules.dim as DimModule
import qs.modules.corners as CornersModule
import qs.modules.kagi as KagiModule
import qs.modules.dengen as DengenModule
import qs.modules.polkit as PolkitModule
import qs.modules.settei as SetteiModule
import qs.modules.hiroba as HirobaModule
import qs.modules.haichi as HaichiModule
import qs.modules.fune as FuneModule
import qs.ipc as IpcModule

// OcarinaShell オカリナシェル — one `qs` process for bar, island, wallpaper, OSD… (docs/01-ARQUITECTURA).
// Launch always as `qs -c ocarina` (ocarinashell.service). Every module is loaded in isolation by ModuleLoader:
// if one breaks after an update only that one is missing (docs/06 capa 3); see Health / `ocarina doctor`.
ShellRoot {
    id: shell

    // The island, the full bar and the notifications live on the primary screen (配置 Haichi: the profile's choice,
    // else the laptop panel, else the first screen).
    readonly property string primary: Displays.primary

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property ShellScreen modelData

            ModuleLoader {
                name: "Kabegami · " + perScreen.modelData.name
                source: Qt.resolvedUrl("modules/kabegami/Wallpaper.qml")
                props: ({ screen: perScreen.modelData })
            }
            ModuleLoader {
                id: obi
                name: "Obi · " + perScreen.modelData.name
                source: Qt.resolvedUrl("modules/obi/ObiWindow.qml")
                fallback: Qt.resolvedUrl("modules/obi/ObiWindowPlain.qml")
                props: ({ screen: perScreen.modelData, island: perScreen.modelData.name === shell.primary })
            }
            ModuleLoader {
                id: panelHost
                name: "Paneles · " + perScreen.modelData.name
                active: ((Panels.open !== "" || Panels.dragging !== "") && Panels.screen === perScreen.modelData.name) || hostAlive
                property bool hostAlive: false
                source: Qt.resolvedUrl("modules/panels/PanelHostBlur.qml")
                fallback: Qt.resolvedUrl("modules/panels/PanelHost.qml")
                props: ({ screen: perScreen.modelData })
                onItemChanged: if (item) { hostAlive = true; item.finished.connect(() => hostAlive = false); }
            }
            ModuleLoader {
                name: "Torii · " + perScreen.modelData.name
                source: Qt.resolvedUrl("modules/torii/ToriiWindowBlur.qml")
                fallback: Qt.resolvedUrl("modules/torii/ToriiWindow.qml")
                props: ({ screen: perScreen.modelData })
            }
            ModuleLoader {
                name: "Dengen · " + perScreen.modelData.name
                active: Dengen.open && Dengen.screen === perScreen.modelData.name
                source: Qt.resolvedUrl("modules/dengen/DengenWindowBlur.qml")
                fallback: Qt.resolvedUrl("modules/dengen/DengenWindow.qml")
                props: ({ screen: perScreen.modelData })
            }
            // さようなら the farewell: Plymouth's first shutdown frame, on every screen, until the session ends
            ModuleLoader {
                name: "Despedida · " + perScreen.modelData.name
                active: Dengen.leaving
                source: Qt.resolvedUrl("modules/dengen/Farewell.qml")
                props: ({ screen: perScreen.modelData })
            }
            ModuleLoader {
                name: "Fumi · " + perScreen.modelData.name
                active: perScreen.modelData.name === shell.primary && Notifs.popups.length > 0
                source: Qt.resolvedUrl("modules/fumi/Toasts.qml")
                props: ({ screen: perScreen.modelData })
            }
            ModuleLoader {
                name: "Atenuación · " + perScreen.modelData.name
                active: Brightness.softLevel(perScreen.modelData.name) < 100
                source: Qt.resolvedUrl("modules/dim/DimWindow.qml")
                props: ({ screen: perScreen.modelData })
            }
            // 配置 Haichi: giant numeral for «Identificar» (2 s) and the Esc catcher on the presenting copy
            ModuleLoader {
                name: "Haichi · " + perScreen.modelData.name
                active: Displays.identifying || (Displays.mirroring && Displays.mirrorTarget === perScreen.modelData.name)
                source: Qt.resolvedUrl("modules/haichi/ScreenTag.qml")
                props: ({ screen: perScreen.modelData })
            }
            // 滑 Fluido: OSD (1,2 s) and the «armando» hint, on the target's screen (or the primary one)
            ModuleLoader {
                name: "Fluido · " + perScreen.modelData.name
                active: (Nameraka.osdShown || Nameraka.arming)
                        && perScreen.modelData.name === ((Nameraka.info.output ?? "") !== "" ? Nameraka.info.output : shell.primary)
                source: Qt.resolvedUrl("modules/nameraka/FlowOsd.qml")
                props: ({ screen: perScreen.modelData })
            }
            // 鬼 «覚醒»: the red edge glow, 600 ms once when Oni starts
            ModuleLoader {
                name: "Oni · 覚醒 · " + perScreen.modelData.name
                active: Modes.kakusei
                source: Qt.resolvedUrl("modules/oni/Kakusei.qml")
                props: ({ screen: perScreen.modelData })
            }
            ModuleLoader {
                name: "Esquinas · " + perScreen.modelData.name
                active: Settings.data.appearance.screenCorners
                source: Qt.resolvedUrl("modules/corners/Corners.qml")
                props: ({ screen: perScreen.modelData })
            }
        }
    }

    // Never hot-reload under a lock: a reload re-creates Lock (and its WlSessionLock) mid-lock (fase 06, D-045)
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: !Lock.active
    }

    Connections {
        target: Niri
        function onLayoutSwitched(name) { Osd.show("info", 0, "Teclado · " + name, "keyboard"); }
    }
    Connections {
        target: Settings
        function onCorrupted(backupPath) {
            const kept = Settings.keptLive;
            const what = backupPath === "" ? "No se pudo copiar el fichero dañado: no se tocará hasta que lo arregles."
                : (kept ? "Se mantienen tus ajustes de esta sesión" : "Se usan los valores por defecto")
                  + ". Copia del fichero dañado: " + backupPath;
            Osd.show("info", 0, kept ? "Ajustes dañados: se mantienen los de esta sesión"
                                     : "Ajustes dañados: valores por defecto", "warning");
            // a lasting notice too (Fumi's history keeps it; the OSD is gone in 2 s)
            Quickshell.execDetached(["notify-send", "-a", "OcarinaShell", "-u", "critical", "-i", "dialog-warning",
                                     "-h", "string:x-ocarina-kanji:殻", "settings.json dañado", what]);
        }
    }

    // 鍵 Kagi: always loaded (idle it is just an unlocked WlSessionLock). If it cannot load, Lock falls back to swaylock.
    ModuleLoader {
        name: "Kagi"
        source: Qt.resolvedUrl("modules/kagi/Kagi.qml")
    }

    // 認 polkit agent: registered at startup; the dialog exists only during a request
    ModuleLoader {
        name: "Polkit"
        source: Qt.resolvedUrl("modules/polkit/Polkit.qml")
    }

    // 設定 Settei: a normal window, created only while open
    ModuleLoader {
        name: "Settei"
        active: Settei.open
        source: Qt.resolvedUrl("modules/settei/SetteiWindow.qml")
    }

    ModuleLoader {
        name: "IPC"
        source: Qt.resolvedUrl("ipc/Ipc.qml")
    }

    // Start the event-driven services (singletons are created on first access): what the bar and the lock need at
    // once, the rest a moment after the first frame (fase 17: 26 singletons before the mark cost ~50 ms of start-up)
    Component.onCompleted: {
        const touch = [Settings.ready, Theme.id, Niri.available, Time.hhmm, Audio.available, Power.percent, Media.active,
                       Notifs.dnd, Lock.active, Idle.inhibit];
        const ms = Date.now() - Quickshell.launchTime.getTime();
        console.info(ms < 10000 ? "OcarinaShell: arranque " + ms + " ms" : "OcarinaShell: recarga en caliente");
        later.start();
    }
    Timer {
        id: later
        interval: 250
        onTriggered: {
            const touch = [Kisetsu.ko, Brightness.entries, Weather.available, Hogo.phase, NightLight.mode, Focus.active,
                           NiriConf.loaded, ThemeCtl.busy, Displays.count, Recorder.recording, Session.mode, TermFx.want,
                           Honban.prod, KbdLight.available, Fune.checked, Mamori.available];
        }
    }
}
