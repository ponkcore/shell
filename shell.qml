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
}
