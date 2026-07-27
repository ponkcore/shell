import QtQuick
import Quickshell
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily.
        // GameMode and VPN are removed in this fork (see OWNERSHIP.md).

        IdleInhibitor;
        Notifs;
        Players;
        Brightness;
        Weather.reload();
    }
}
