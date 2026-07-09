pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Bridge to the local `lecoo-power-mode` contract command.
// Provides power mode state (eco+, eco, balanced, performance) to
// shell UI components. Falls back gracefully on non-Lecoo systems.
// See: /etc/nixos/hosts/lecoo/home/scripts.nix

Singleton {
    id: root

    // Whether the lecoo-power-mode command is available on this host.
    property bool available: false

    // Current power mode string: "eco+", "eco", "balanced",
    // "performance", or "unknown" when unavailable / unreadable.
    property string currentMode: "unknown"

    // Ordered modes for UI display — eco+ is leftmost per user spec.
    readonly property list<string> modes: ["eco+", "eco", "balanced", "performance"]

    // Per-mode display metadata.
    readonly property var modeInfo: ({
        "eco+": { "icon": "battery_saver", "label": "Eco+" },
        "eco": { "icon": "energy_savings_leaf", "label": "Eco" },
        "balanced": { "icon": "balance", "label": "Balanced" },
        "performance": { "icon": "rocket_launch", "label": "Performance" }
    })

    // Refresh currentMode by calling `lecoo-power-mode get`.
    function refresh(): void {
        getProc.running = true
    }

    // Set a new power mode. Fire-and-forget, then refresh after
    // a short delay so the UI reflects the new state.
    function setMode(mode: string): void {
        if (!root.available)
            return
        if (!root.modes.includes(mode))
            return
        Quickshell.execDetached(["lecoo-power-mode", "set", mode])
        refreshTimer.start()
    }

    Component.onCompleted: {
        // Check availability first, then read initial state.
        availProc.running = true
    }

    // Availability check: `command -v lecoo-power-mode`.
    Process {
        id: availProc

        command: ["sh", "-c", "command -v lecoo-power-mode >/dev/null 2>&1 && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim()
                root.available = result === "yes"
                if (root.available)
                    root.refresh()
            }
        }
    }

    // State read: `lecoo-power-mode get`.
    Process {
        id: getProc

        command: ["lecoo-power-mode", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const mode = text.trim()
                if (mode.length > 0)
                    root.currentMode = mode
            }
        }
    }

    // Delayed refresh after a set operation.
    Timer {
        id: refreshTimer

        interval: 600
        onTriggered: root.refresh()
    }
}
