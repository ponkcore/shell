//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/lock"
import "modules/areapicker"
import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

// Phase 3e: Lock and IdleMonitors are now enabled — Caelestia
// owns the lock/idle path. hyprlock and hypridle are disabled
// in the NixOS config. See ARCHITECTURE_SPLIT.md §11 Phase 3.

ShellRoot {
    id: root

    settings.watchFiles: true

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}

    Background {}
    Drawers {}
    AreaPicker {}

    Lock {
        id: lock
    }

    IdleMonitors {
        lock: lock
    }

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}

    // Force instantiation of Lecoo bridge singletons so they read
    // initial state at shell startup, not lazily on first UI access.
    // Without this, singletons that no loaded component references
    // directly would never start. See CRITICAL LESSONS #7.
    QtObject {
        property bool lecooPowerReady: LecooPower.available
        property string lecooPowerMode: LecooPower.currentMode
        property bool lecooChargeReady: LecooCharge.available
        property string lecooChargeMode: LecooCharge.currentMode
    }

    // Eco+ animation kill switch. Tokens.anim.durations is the global
    // AnimDurations object (CONFIG_GLOBAL_PROPERTY, shared across all
    // Tokens instances via GlobalConfig). Setting scale=0 zeroes every
    // animation duration across the shell — drawers, popouts, bar
    // indicators, state layers, color transitions — because all
    // Anim/AnchorAnim/CAnim components read from
    // Tokens.anim.durations.* which multiplies by scale.
    // No per-component changes needed. Reacts to LecooPower.currentMode
    // changes (optimistic from UI setMode + 5s poll for external switches).
    Item {
        id: animScaleBridge
        visible: false

        Binding {
            target: animScaleBridge.Tokens.anim.durations
            property: "scale"
            value: LecooPower.available && LecooPower.currentMode === "eco+" ? 0 : 1
        }
    }
}
