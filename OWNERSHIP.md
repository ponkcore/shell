# Ownership Model

## Principle

This fork follows the **upstream-first Caelestia migration path**.

- **Nix owns the substrate**: platform, hardware, security, PAM,
  services, session wiring, package builds, version pinning.
- **This fork owns the shell product**: shell UI modules, component
  library, service singletons, theme/token system, launcher UX,
  dashboard/session/OSD/notifications/lock/wallpaper UX, shell
  runtime state model, shell config schema and defaults.
- **Runtime owns shell live state**: shell JSON config/state,
  monitor overrides, current scheme/theme mode/variant, current
  wallpaper selection, notification history, launcher frequency DB,
  cached generated previews/images.

Shell runtime state is **not** required to live entirely inside Nix.
The shell may read and write JSON/config state under
`~/.config/caelestia/` and `~/.local/state/caelestia/` at runtime.

## Removed subsystems

The following upstream subsystems are **removed** in this fork and
must not be reintroduced:

- `services/VPN.qml` — VPN stack is not aligned with our proxy/VPN
  world (Throne/sing-box). VPN ownership stays outside the shell.
- `services/GameMode.qml` — not a target concern for this desktop.

All QML toggle entries, config properties, C++ config objects, and
toast settings that referenced these subsystems have been removed
from the fork baseline.

## Quickshell source

This shell is built against **upstream git Quickshell**, not the
nixpkgs stable `pkgs.quickshell` package. The exact commit is pinned
in `flake.lock` under the `quickshell` input.
