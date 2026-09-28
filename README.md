# caelestia-shell (ponkcore fork)

Fork of [`caelestia-dots/shell`](https://github.com/caelestia-dots/shell) —
the Caelestia desktop shell built on [Quickshell](https://quickshell.outfoxxed.me)
for [Hyprland](https://hypr.land). This fork is deployed through
[`ponkcore/nix-config`](https://github.com/ponkcore/nix-config), not through the
upstream dotfiles.

See [`OWNERSHIP.md`](OWNERSHIP.md) for what this fork owns versus what stays
upstream, and which upstream subsystems are deliberately removed.

## Repository layout

| Path | Contents |
| --- | --- |
| `plugin/src/Caelestia/` | C++ Qt6 QML plugin — services, config, models, images |
| `components/`, `modules/` | QML component library and shell UI modules |
| `services/`, `utils/` | QML service singletons and helpers |
| `extras/` | version helper library |
| `nix/` | Nix package expression and Home Manager module |
| `scripts/` | `qml-lint-conventions.py`, the QML convention linter CI runs |
| `assets/` | fonts, wallpapers, PAM config, misc images |

## Building

The build requires a Nix devShell — `flake.nix` pins Quickshell from upstream
git (not the nixpkgs stable package) plus the Qt6/clazy toolchain.

```sh
git clone https://github.com/ponkcore/shell.git
cd shell
nix develop          # or: direnv allow, if you read .envrc first
```

`.envrc` configures and builds into `build/` on every entry, using `clazy` as
the C++ compiler. To build explicitly:

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

To produce an installable package without a devShell:

```sh
nix build .#caelestia-shell      # shell only
nix build .#with-cli             # shell + ponkcore/cli
```

The `caelestia-cli` flake input points at
[`ponkcore/cli`](https://github.com/ponkcore/cli). Both forks are wired
together through `nix-config`, which makes each follow the other so the
Quickshell and m3shapes nodes are shared rather than duplicated.

## Deploying

On this host the shell is built from `github:ponkcore/shell/main` by
`nix-config` and runs as the user service `caelestia.service`, launched by
`wayland-session@Hyprland.target`. The running binary comes from the Nix store,
so **a local edit does not reach the screen** — the change must be pushed and
the system rebuilt:

```sh
git push origin main
# then, as the system administrator:
sudo nixos-rebuild switch --flake /etc/nixos#lecoo
systemctl --user restart caelestia.service
```

For throwaway testing without deploying, run a second instance against a local
build — note that two shells on one compositor will fight over layer-shell
surfaces, so stop the service first:

```sh
systemctl --user stop caelestia.service
./result/bin/caelestia-shell
```

## Checking

CI runs three gates. All three reproduce locally from the devShell:

```sh
# QML formatting + fork conventions
for f in $(git ls-files '*.qml'); do qmlformat "$f" | diff -u "$f" - || break; done
python3 scripts/qml-lint-conventions.py

# C++ formatting
find plugin extras -name '*.cpp' -o -name '*.hpp' | xargs clang-format --dry-run --Werror

# QML lint — needs a built plugin so generated types resolve.
# .qmlls.ini is produced by `qs -p .` and carries buildDir/importPaths.
cmake --build build
touch .qmlls.ini && QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/build/qml" timeout 2 qs -p .
qmllint --import disable -I <buildDir> -I <importPaths…> $(git ls-files '*.qml')
```

`qml-lint-conventions.py` enforces the import order used across the tree:
QtQuick, other Qt, Quickshell, M3Shapes, Caelestia, `qs.components`,
`qs.services`, `qs.config`, `qs.utils`, `qs.modules.*`. A singleton that calls
into a sibling singleton must import its own module explicitly
(`import qs.modules.launcher.services`) — relative resolution works at runtime
but leaves `qmllint` unable to see the sibling's members.

## Syncing with upstream

```sh
git fetch upstream
git merge upstream/main
```

Upstream-owned files that this fork intentionally diverges from will conflict.
Re-apply the fork side for `OWNERSHIP.md`, `.github/FUNDING.yml`,
`README.md`, `shell.qml`'s `QS_CRASHREPORT_URL`, and the removed `VPN.qml` /
`GameMode.qml` services. The `flake.nix` Quickshell pin is a fork decision too —
upstream periodically re-locks it.

After a merge, re-run all three checks above: upstream refactors routinely
break `qmllint` on fork-local QML that only exists in this tree.

## Usage

The shell starts from `caelestia.service`, so there is nothing to launch by
hand in normal use. To drive it manually:

```sh
caelestia shell -d      # preferred: detached
qs -c caelestia -n -d
```

Omit `-d` to keep the shell attached to the current terminal.

### Shortcuts/IPC

Keybinds are wired in `nix-config` through Hyprland
[global shortcuts](https://wiki.hypr.land/Configuring/Basics/Binds/#dbus-global-shortcuts),
not in this repo. Upstream's
[`keybinds.lua`](https://github.com/caelestia-dots/caelestia/blob/main/hypr/hyprland/keybinds.lua#L63-L67)
shows the shape of that wiring if you need a reference.

All IPC commands are reachable via `caelestia shell ...`:

```sh
caelestia shell mpris getActive trackTitle
caelestia shell -s        # list available IPC commands
```

### PFP/Wallpapers

The dashboard profile picture is read from `~/.face`; set it by clicking it in
the dashboard, or by copying or symlinking an image to that path.

Wallpapers for the switcher are read from `~/Pictures/Wallpapers` by default.
Change that with `paths.wallpaperDir` in `~/.config/caelestia/shell.json`.

Set a wallpaper either by typing `>wallpaper` in the launcher, or directly:

```sh
caelestia wallpaper -f <path_to_wallpaper>
caelestia wallpaper -h
```

## Updating

This fork is deployed by `nix-config` from `github:ponkcore/shell/main`, so
"updating" means push the branch and rebuild the system — see
[Deploying](#deploying). There is no AUR package and no manual install path for
this fork.

To pull in upstream work, see [Syncing with upstream](#syncing-with-upstream).

## Configuring

All configuration options belong in `~/.config/caelestia/shell.json`. This file is _not_ created by
default; you must create it manually. Options that you omit from the config file will use their default
values.

### Per-monitor configuration

You can configure per-monitor options in `~/.config/caelestia/monitors/<monitor_name>/shell.json`.
List the names of your available monitors by running:

```sh
hyprctl monitors -j | jq -r '.[].name'
```

Options set in these files will **override** the respective options in the global config. Any options not present in
per-monitor configs will inherit their values from the global config.


For example, to automatically hide the bar on the monitor named `DP-1`:

**`~/.config/caelestia/monitors/DP-1/shell.json`**

```json
{
    "bar": {
        "persistent": false
    }
}
```

> [!NOTE]
> Not all options respect per-monitor overrides. Most notably, the following options will only read
> from the global config, and ignore the respective option in per-monitor config files.
>
> <details><summary>Ignored options</summary>
>
> - `appearance`: `anim.*`, `transparency.*`
> - `bar.tray`: `hiddenIcons`, `iconSubs`
> - `bar.workspaces`: `perMonitorWorkspaces`, `specialWorkspaceIcons`, `windowIcons`
> - `dashboard`: `mediaUpdateInterval`, `resourceUpdateInterval`
> - `general`: `apps.*`, `battery.*`, `idle.*`, `logo`
> - `launcher`: `actionPrefix`, `actions`, `enableDangerousActions`, `favouriteApps`, `hiddenApps`, `specialPrefix`, `useFuzzy.*`, `vimKeybinds`
> - `lock`: `enableFprint`, `enableHowdy`, `maxFprintTries`, `maxHowdyTries`, `triggerHowdyOnWake`
> - `nexus`: `networkRescanInterval`
> - `notifs`: `actionOnClick`, `defaultExpireTimeout`, `expire`, `fullscreen`, `fullscreenExpireTimeout`
> - `paths`: `lyricsDir`, `wallpaperDir`
> - `services`: `audioIncrement`, `brightnessIncrement`, `defaultPlayer`, `gpuType`, `lyricsBackend`, `maxVolume`, `playerAliases`, `smartScheme`, `useFahrenheit`, `useFahrenheitPerformance`, `useTwelveHourClock`, `visualiserBars`, `weatherLocation`
> - `utilities.toasts`: all except `fullscreen`
>
> </details>

### Example configuration

> [!WARNING]
> The example configuration includes **ALL** configuration options in `shell.json`. It is
> **not** recommended to copy and paste this entire configuration into `shell.json`,
> as options or their default values may change across updates, resulting in a stale config.
>
> This is meant to serve as a reference of all the available options, and you should
> <ins>only add the ones you want to change</ins> to `shell.json`.

<details><summary>Example config</summary>

```json
{
    "enabled": true,
    "appearance": {
        "deformScale": 1,
        "rounding": {
            "scale": 1
        },
        "spacing": {
            "scale": 1
        },
        "padding": {
            "scale": 1
        },
        "font": {
            "scale": 1,
            "clock": "Rubik",
            "workspaces": "Rubik",
            "headline": {
                "family": "GoogleSansFlex",
                "large": { "size": 32, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 28, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 24, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "title": {
                "family": "GoogleSansFlex",
                "large": { "size": 22, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 16, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 14, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "body": {
                "family": "GoogleSansFlex",
                "large": { "size": 16, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 14, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 12, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "label": {
                "family": "GoogleSansFlex",
                "large": { "size": 14, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 12, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 11, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "mono": {
                "family": "CaskaydiaCove NF",
                "large": { "size": 16, "weight": 400, "italic": false, "vaxes": {} },
                "medium": { "size": 14, "weight": 400, "italic": false, "vaxes": {} },
                "small": { "size": 12, "weight": 400, "italic": false, "vaxes": {} }
            },
            "icon": {
                "family": "Material Symbols Rounded",
                "extraLarge": { "size": 36, "weight": 400, "italic": false, "vaxes": {} },
                "large": { "size": 24, "weight": 400, "italic": false, "vaxes": {} },
                "medium": { "size": 18, "weight": 400, "italic": false, "vaxes": {} },
                "small": { "size": 15, "weight": 400, "italic": false, "vaxes": {} }
            }
        },
        "anim": {
            "durations": {
                "scale": 1
            }
        },
        "transparency": {
            "enabled": false,
            "base": 0.85,
            "layers": 0.4
        }
    },
    "general": {
        "logo": "",
        "showOverFullscreen": false,
        "mediaGifSpeedAdjustment": 300,
        "sessionGifSpeed": 0.7,
        "apps": {
            "terminal": ["foot"],
            "audio": ["pwvucontrol"],
            "playback": ["mpv"],
            "explorer": ["thunar"]
        },
        "idle": {
            "lockBeforeSleep": true,
            "inhibitWhenAudio": true,
            "inhibitWhenCharging": false,
            "timeouts": [
                {
                    "timeout": 180,
                    "idleAction": "lock",
                    "inhibitWhenAudio": false,
                    "inhibitWhenCharging": false,
                    "respectInhibitors": true
                },
                {
                    "timeout": 300,
                    "idleAction": "dpms off",
                    "returnAction": "dpms on"
                },
                {
                    "timeout": 600,
                    "idleAction": ["suspendThenHibernate"]
                }
            ]
        },
        "battery": {
            "warnLevels": [
                {
                    "level": 20,
                    "title": "Low battery",
                    "message": "You might want to plug in a charger",
                    "icon": "battery_android_frame_2"
                },
                {
                    "level": 10,
                    "title": "Did you see the previous message?",
                    "message": "You should probably plug in a charger <b>now</b>",
                    "icon": "battery_android_frame_1"
                },
                {
                    "level": 5,
                    "title": "Critical battery level",
                    "message": "PLUG THE CHARGER RIGHT NOW!!",
                    "icon": "battery_android_alert",
                    "critical": true
                }
            ],
            "criticalLevel": 3
        }
    },
    "background": {
        "enabled": true,
        "wallpaperEnabled": true,
        "desktopClock": {
            "enabled": false,
            "scale": 1.0,
            "position": "bottom-right",
            "invertColors": false,
            "background": {
                "enabled": false,
                "opacity": 0.7,
                "blur": true
            },
            "shadow": {
                "enabled": true,
                "opacity": 0.7,
                "blur": 0.4
            }
        },
        "visualiser": {
            "enabled": false,
            "autoHide": true,
            "blur": false,
            "rounding": 1,
            "spacing": 1
        }
    },
    "bar": {
        "persistent": true,
        "showOnHover": true,
        "dragThreshold": 20,
        "scrollActions": {
            "workspaces": true,
            "volume": true,
            "brightness": true
        },
        "popouts": {
            "activeWindow": true,
            "tray": true,
            "statusIcons": true
        },
        "workspaces": {
            "shown": 5,
            "activeIndicator": true,
            "occupiedBg": false,
            "showWindows": true,
            "showWindowsOnSpecialWorkspaces": true,
            "maxWindowIcons": 5,
            "activeTrail": false,
            "perMonitorWorkspaces": true,
            "label": "  ",
            "occupiedLabel": "󰮯",
            "activeLabel": "󰮯",
            "capitalisation": "preserve",
            "specialWorkspaceIcons": [
                {
                    "name": "steam",
                    "icon": "sports_esports"
                }
            ],
            "windowIcons": [
                {
                    "regex": "steam(_app_(default|[0-9]+))?",
                    "icon": "sports_esports"
                }
            ]
        },
        "activeWindow": {
            "compact": false,
            "inverted": false,
            "showOnHover": true
        },
        "tray": {
            "background": false,
            "recolour": false,
            "compact": false,
            "iconSubs": [],
            "hiddenIcons": []
        },
        "clock": {
            "background": false,
            "showDate": false,
            "showIcon": true
        },
        "statusIcons": [
            {
                "id": "lockStatus",
                "enabled": true
            },
            {
                "id": "audio",
                "enabled": false
            },
            {
                "id": "microphone",
                "enabled": false
            },
            {
                "id": "kbLayout",
                "enabled": false
            },
            {
                "id": "network",
                "enabled": true
            },
            {
                "id": "bluetooth",
                "enabled": true
            },
            {
                "id": "battery",
                "enabled": true
            }
        ],
        "entries": [
            {
                "id": "logo",
                "enabled": true
            },
            {
                "id": "workspaces",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "activeWindow",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "tray",
                "enabled": true
            },
            {
                "id": "clock",
                "enabled": true
            },
            {
                "id": "statusIcons",
                "enabled": true
            },
            {
                "id": "power",
                "enabled": true
            }
        ],
        "excludedScreens": []
    },
    "border": {
        "thickness": 10,
        "rounding": 25,
        "smoothing": 20
    },
    "dashboard": {
        "enabled": true,
        "showOnHover": true,
        "showDashboard": true,
        "showMedia": true,
        "showPerformance": true,
        "showWeather": true,
        "mediaUpdateInterval": 500,
        "resourceUpdateInterval": 1000,
        "dragThreshold": 50,
        "performance": {
            "showBattery": true,
            "showGpu": true,
            "showCpu": true,
            "showMemory": true,
            "showStorage": true,
            "showNetwork": true
        }
    },
    "launcher": {
        "enabled": true,
        "showOnHover": false,
        "maxShown": 7,
        "maxWallpapers": 9,
        "specialPrefix": "@",
        "actionPrefix": ">",
        "enableDangerousActions": false,
        "dragThreshold": 50,
        "vimKeybinds": false,
        "favouriteApps": [],
        "hiddenApps": [],
        "useFuzzy": {
            "apps": false,
            "actions": false,
            "schemes": false,
            "variants": false,
            "wallpapers": false
        },
        "actions": [
            {
                "name": "Calculator",
                "icon": "calculate",
                "description": "Do simple math equations (powered by Qalc)",
                "command": ["autocomplete", "calc"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Scheme",
                "icon": "palette",
                "description": "Change the current colour scheme",
                "command": ["autocomplete", "scheme"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Wallpaper",
                "icon": "image",
                "description": "Change the current wallpaper",
                "command": ["autocomplete", "wallpaper"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Variant",
                "icon": "colors",
                "description": "Change the current scheme variant",
                "command": ["autocomplete", "variant"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Random",
                "icon": "casino",
                "description": "Switch to a random wallpaper",
                "command": ["caelestia", "wallpaper", "-r"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Light",
                "icon": "light_mode",
                "description": "Change the scheme to light mode",
                "command": ["setMode", "light"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Dark",
                "icon": "dark_mode",
                "description": "Change the scheme to dark mode",
                "command": ["setMode", "dark"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Shutdown",
                "icon": "power_settings_new",
                "description": "Shutdown the system",
                "command": ["poweroff"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Reboot",
                "icon": "cached",
                "description": "Reboot the system",
                "command": ["reboot"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Logout",
                "icon": "exit_to_app",
                "description": "Log out of the current session",
                "command": ["logout"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Lock",
                "icon": "lock",
                "description": "Lock the current session",
                "command": ["loginctl", "lock-session"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Sleep",
                "icon": "bedtime",
                "description": "Suspend then hibernate",
                "command": ["suspendThenHibernate"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Settings",
                "icon": "settings",
                "description": "Configure the shell",
                "command": ["caelestia", "shell", "nexus", "open"],
                "enabled": true,
                "dangerous": false
            }
        ]
    },
    "lock": {
        "enabled": true,
        "useWallpaper": false,
        "recolourLogo": true,
        "enableFprint": true,
        "maxFprintTries": 3,
        "enableHowdy": true,
        "maxHowdyTries": 3,
        "triggerHowdyOnWake": true,
        "hideNotifs": false
    },
    "nexus": {
        "wallpapersPerRow": 4,
        "networkRescanInterval": 15000
    },
    "notifs": {
        "expire": true,
        "fullscreen": "on",
        "defaultExpireTimeout": 5000,
        "fullscreenExpireTimeout": 2000,
        "clearThreshold": 0.3,
        "expandThreshold": 20,
        "actionOnClick": false,
        "groupPreviewNum": 3,
        "openExpanded": false
    },
    "osd": {
        "enabled": true,
        "hideDelay": 2000,
        "enableBrightness": true,
        "enableMicrophone": false
    },
    "services": {
        "weatherLocation": "",
        "useFahrenheit": false,
        "useFahrenheitPerformance": false,
        "useTwelveHourClock": false,
        "gpuType": "",
        "visualiserBars": 60,
        "audioIncrement": 0.1,
        "brightnessIncrement": 0.1,
        "maxVolume": 1.0,
        "smartScheme": true,
        "defaultPlayer": "Spotify",
        "playerAliases": [{ "from": "com.github.th_ch.youtube_music", "to": "YT Music" }],
        "lyricsBackend": "Auto"
    },
    "session": {
        "enabled": true,
        "dragThreshold": 30,
        "vimKeybinds": false,
        "icons": {
            "logout": "logout",
            "shutdown": "power_settings_new",
            "hibernate": "downloading",
            "reboot": "cached"
        },
        "commands": {
            "logout": ["logout"],
            "shutdown": ["poweroff"],
            "hibernate": ["hibernate"],
            "reboot": ["reboot"]
        }
    },
    "sidebar": {
        "enabled": true,
        "showOnHover": false,
        "minHoverThreshold": 200,
        "dragThreshold": 80
    },
    "utilities": {
        "enabled": true,
        "maxToasts": 4,
        "toasts": {
            "fullscreen": "off",
            "configLoaded": true,
            "chargingChanged": true,
            "dndChanged": true,
            "audioOutputChanged": true,
            "audioInputChanged": true,
            "capsLockChanged": true,
            "numLockChanged": true,
            "kbLayoutChanged": true,
            "kbLimit": true,
            "nowPlaying": false
        },
        "quickToggles": [
            {
                "id": "wifi",
                "enabled": true
            },
            {
                "id": "bluetooth",
                "enabled": true
            },
            {
                "id": "mic",
                "enabled": true
            },
            {
                "id": "settings",
                "enabled": true
            },
            {
                "id": "dnd",
                "enabled": true
            }
        ]
    },
    "paths": {
        "wallpaperDir": "~/Pictures/Wallpapers",
        "lyricsDir": "~/Music/lyrics/",
        "sessionGif": "root:/assets/kurukuru.gif",
        "mediaGif": "root:/assets/bongocat.gif",
        "noNotifsPic": "root:/assets/dino.png",
        "lockNoNotifsPic": "root:/assets/dino.png"
    }
}
```

</details>

### Advanced configuration

> [!CAUTION]
> Do NOT change any of these options unless you know what you are doing. These options control the
> tokens used internally within the shell, and can cause visual issues if modified incorrectly.
> The available options may change or be removed without notice across versions.

A separate `~/.config/caelestia/shell-tokens.json` file allows editing the internal tokens without
touching the source code of the shell. These tokens affect the dimensions and appearance of visual elements,
including individual rounding, spacing, padding, font size, animation durations and curves, and the sizes of
certain components. The appearance scale values in `shell.json` are multiplied against these base
token values to produce the final computed values.

Per-monitor token overrides are also available at
`~/.config/caelestia/monitors/<monitor_name>/shell-tokens.json`.

### Home Manager Module

The fork ships a Home Manager module at `nix/hm-module.nix`, exposed as
`caelestia-shell.homeManagerModules.default`. This is how the shell is deployed
on this host.

> [!IMPORTANT]
> Do **not** populate the `settings` attrset. HM `settings` writes
> `~/.config/caelestia/shell.json` as a read-only Nix store symlink via
> `xdg.configFile`, which stops the shell from persisting runtime state
> (wallpaper changes, bar toggles, scheme selection). Keep `settings = {}` and
> write the config as a real writable file from `home.activation` instead —
> that is what `nix-config` does.

<details><summary><code>home.nix</code></summary>

```nix
programs.caelestia = {
  enable = true;
  systemd = {
    enable = false; # if you prefer starting from your compositor
    target = "graphical-session.target";
    environment = [];
  };
  settings = {
    bar.statusIcons = [
      { id = "lockStatus"; enabled = true; }
      { id = "network"; enabled = true; }
      { id = "bluetooth"; enabled = true; }
      { id = "battery"; enabled = false; }
    ];
    paths.wallpaperDir = "~/Images";
  };
  cli = {
    enable = true; # Also add caelestia-cli to path
    settings = {
      theme.enableGtk = false;
    };
  };
};
```

The module adds the shell to the path with **full functionality** when the
package is the `with-cli` override. The CLI is optional, but wallpaper, scheme
and IPC features need it.

</details>

## FAQ

### Where do I get help?

Upstream issues and the
[Caelestia Discord](https://caelestiashell.com/discord) cover stock shell
behaviour. For anything specific to this fork — the Lecoo power bridge,
CloakBrowser profile picker, launch-detach behaviour, removed VPN/GameMode
services — file an issue on [`ponkcore/shell`](https://github.com/ponkcore/shell/issues)
instead, so it does not land on the upstream maintainers.

### I want to change the Hyprland config

Hyprland is owned by `nix-config`, not by this repo. Session, keybinds and
compositor settings live under `/etc/nixos`.

### I want to disable a feature

Read the [Configuring](#configuring) section. If there is no corresponding
option, open a [feature request](https://github.com/ponkcore/shell/issues/new).

### How do I make my colour scheme change to match my wallpaper?

Set a wallpaper via `>wallpaper` in the launcher or `caelestia wallpaper`, and
set the scheme to the dynamic scheme via `>scheme` in the launcher or
`caelestia scheme set`:

```sh
caelestia wallpaper -f <path_to_wallpaper>
caelestia scheme set -n dynamic
```

### My wallpapers aren't showing up in the launcher!

The launcher pulls wallpapers from `~/Pictures/Wallpapers` by default; change
that in the config. It also only shows an odd number of wallpapers at a time,
so with exactly 2 it may look empty.

## Known issues

Tracked in this repo, not upstream:

- **Dropdown menus are not clickable in some positions.** `Menu.qml` popups
  escape the SplitButton `Row` positioner and lose input in the utilities
  drawer (record mode selector). A chain of fix attempts was rolled back in
  `0e1ce334`; the bug is open again. See
  [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## Credits

This fork builds on [`caelestia-dots/shell`](https://github.com/caelestia-dots/shell)
by [@soramanew](https://github.com/soramanew), which is where nearly all of the
design and most of the code come from.

Upstream's own acknowledgements, retained:

Thanks to the Hyprland Discord community (especially #rice-discussion) for the
help and suggestions that shaped these dots.

A special thanks to [@outfoxxed](https://github.com/outfoxxed) for making
Quickshell and for the effort put into fixing issues and implementing feature
requests.

Another special thanks to [@end_4](https://github.com/end-4) for his
[config](https://github.com/end-4/dots-hyprland), which helped a lot with
learning how to use Quickshell.

And to [Axenide/Ax-Shell](https://github.com/Axenide/Ax-Shell) for inspiration.
