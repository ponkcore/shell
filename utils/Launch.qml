pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Launch a detached command in its own transient systemd user unit
    // (app-graphical.slice) instead of a direct child of the shell
    // process. Without this, launched applications live inside the
    // caelestia.service cgroup and are SIGKILLed whenever the shell
    // restarts (e.g. on nixos-rebuild switch).
    //
    // The transient unit inherits the systemd user-manager environment
    // (WAYLAND_DISPLAY, DISPLAY, PATH, HYPRLAND_INSTANCE_SIGNATURE are
    // all present there under Hyprland/UWSM sessions).
    function exec(command, workingDirectory) {
        const argv = ["systemd-run", "--user", "--collect", "--quiet", "--slice=app-graphical.slice"];
        if (workingDirectory)
            argv.push(`--working-directory=${workingDirectory}`);
        argv.push("--");
        for (const arg of command)
            argv.push(String(arg));
        Quickshell.execDetached(argv);
    }
}
