//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import QtQuick
import Quickshell
import qs.services

// Phase 3a: Background is re-enabled — Caelestia now owns wallpaper.
// Lock and IdleMonitors remain disabled — hyprlock and hypridle
// are still the active owners. These will be re-enabled at their
// respective ownership cutover phases.
// See ARCHITECTURE_SPLIT.md §11 Phase 3.

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

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
}
