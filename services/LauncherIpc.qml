pragma Singleton

import Quickshell

Singleton {
    // Set by the "launcher" IpcHandler in modules/Shortcuts.qml when an external
    // caller asks to open the launcher with pre-typed search text. Persisted so it
    // survives the launcher being closed/unloaded; consumed (and cleared) by
    // modules/launcher/Content.qml once the search field applies it.
    property string pendingSearch: ""

    signal launcherSearchRequested(string text)

    function request(text: string): void {
        pendingSearch = text;
        launcherSearchRequested(text);
    }

    function consume(): string {
        const text = pendingSearch;
        pendingSearch = "";
        return text;
    }
}
