pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Bridge to the local `lecoo-charge-mode` contract command.
// Provides charge-limit mode state (full, high, balanced, lifespan,
// desk) to shell UI components. Falls back gracefully on non-Lecoo
// systems.
// See: /etc/nixos/hosts/lecoo/home/scripts.nix

Singleton {
    id: root

    // Whether the lecoo-charge-mode command is available on this host.
    property bool available: false

    // Current charge mode string: "full", "high", "balanced",
    // "lifespan", "desk", or "unknown" when unavailable / unreadable.
    property string currentMode: "unknown"

    // Numeric charge limit percent (0-100), parsed from `status` JSON.
    property int currentPercent: 0

    // Ordered modes for UI display.
    readonly property list<string> modes: ["full", "high", "balanced", "lifespan", "desk"]

    // Per-mode display metadata.
    readonly property var modeInfo: ({
        "full": { "label": "100%", "percent": 100 },
        "high": { "label": "95%", "percent": 95 },
        "balanced": { "label": "80%", "percent": 80 },
        "lifespan": { "label": "60%", "percent": 60 },
        "desk": { "label": "40%", "percent": 40 }
    })

    // Refresh currentMode and currentPercent by calling
    // `lecoo-charge-mode status` (returns JSON).
    function refresh(): void {
        statusProc.running = true
    }

    // Set a new charge mode. Optimistically update currentMode
    // for instant UI feedback, then confirm via refresh after
    // the command has had time to take effect.
    function setMode(mode: string): void {
        if (!root.available)
            return
        if (!root.modes.includes(mode))
            return
        root.currentMode = mode
        Quickshell.execDetached(["lecoo-charge-mode", "set", mode])
        refreshTimer.start()
    }

    Component.onCompleted: {
        availProc.running = true
    }

    // Availability check.
    Process {
        id: availProc

        command: ["sh", "-c", "command -v lecoo-charge-mode >/dev/null 2>&1 && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim()
                root.available = result === "yes"
                if (root.available)
                    root.refresh()
            }
        }
    }

    // State read: `lecoo-charge-mode status` returns JSON.
    Process {
        id: statusProc

        command: ["lecoo-charge-mode", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                if (raw.length === 0)
                    return
                try {
                    const json = JSON.parse(raw)
                    root.currentMode = json.mode || "unknown"
                    root.currentPercent = json.percent || 0
                } catch (e) {
                    // JSON parse failure — keep previous state.
                }
            }
        }
    }

    // Delayed refresh after a set operation.
    Timer {
        id: refreshTimer

        interval: 600
        onTriggered: root.refresh()
    }

    // Periodic refresh to catch external state changes.
    // Runs every 5 seconds.
    Timer {
        id: pollTimer

        interval: 5000
        repeat: true
        running: root.available
        onTriggered: root.refresh()
    }
}
