//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/areapicker"
import QtQuick
import Quickshell
import qs.services

// Phase 2 gate: Background, Lock, and IdleMonitors are disabled
// because hyprpaper, hyprlock, and hypridle are still the active
// owners of wallpaper, lock, and idle management. These modules
// will be re-enabled at their respective ownership cutover phases.
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

    Drawers {}
    AreaPicker {}

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
}
