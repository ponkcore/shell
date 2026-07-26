pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.utils
import "../../../utils/scripts/fzf.js" as Fzf
import "../../../utils/scripts/fuzzysort.js" as Fuzzy

Searcher {
    id: root

    readonly property string profilesPath: `${Paths.home}/.config/cloakbrowser/profiles.json`

    property list<var> profiles: []
    property int revision: 0
    property string createName: ""

    // Picker mode (entered by clicking the CloakBrowser app entry):
    // AppList shows profiles regardless of search text.
    property bool pickerActive: false
    // "list" | "create" | "delete" — picker sub-flow.
    property string pickerFlow: "list"

    signal pickerRequested

    function startPicker(): void {
        pickerFlow = "list";
        pickerActive = true;
        revision++;
        pickerRequested();
    }

    function stopPicker(): void {
        pickerActive = false;
        pickerFlow = "list";
        createName = "";
        revision++;
    }

    function isCreateMode(): bool {
        return pickerActive && pickerFlow === "create";
    }

    function isDeleteMode(): bool {
        return pickerActive && pickerFlow === "delete";
    }

    function transformSearch(search: string): string {
        return search.trim();
    }

    function selector(item: var): string {
        return item.name;
    }


    // Nerd Font glyphs (not emoji, not Material Symbols) for row icons.
    // Rendered with a Nerd Font family in CloakItem. Unknown platforms get a
    // generic globe glyph so no row renders an empty icon.
    function osGlyph(platform: string): string {
        const p = String(platform).toLowerCase();
        if (p === "windows")
            return "";
        if (p === "macos")
            return "";
        if (p === "linux")
            return "";
        return "";
    }

    function profileExists(name: string): bool {
        return profiles.some(p => p.name === name);
    }

    function validateName(name: string): bool {
        return /^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(name) && !profileExists(name);
    }

    // revision is read so bindings re-evaluate when profiles reload.
    function query(search: string): list<var> {
        void revision;

        const kind = isCreateMode() ? "create" : isDeleteMode() ? "delete" : "list";


        let items = [];
        if (kind === "create") {
            if (createName.length === 0) {
                items = [{
                        kind,
                        action: "hint",
                        name: qsTr("New profile"),
                        desc: qsTr("Type a name, press Enter"),
                        glyph: ""
                    }];
            } else {
                items = ["windows", "macos", "linux"].map(p => ({
                            kind,
                            action: "platform",
                            name: p,
                            desc: qsTr("Create %1 with platform %2").arg(createName).arg(p),
                            glyph: osGlyph(p)
                        }));
            }
        } else {
            if (kind === "list") {
                items.push({
                    kind,
                    action: "create",
                    name: qsTr("Create profile..."),
                    desc: qsTr("Create a new CloakBrowser profile"),
                    glyph: ""
                }, {
                    kind,
                    action: "delete",
                    name: qsTr("Delete profile..."),
                    desc: qsTr("Delete an existing CloakBrowser profile"),
                    glyph: ""
                });
            }

            for (const p of profiles)
                items.push({
                    kind,
                    action: kind === "delete" ? "confirmDelete" : "launch",
                    name: p.name,
                    desc: kind === "delete" ? qsTr("%1 — click to delete").arg(p.platform) : p.platform,
                    glyph: osGlyph(p.platform)
                });
        }

        // In the create name step the hint row must survive filtering: the typed
        // text is the new profile name, not a query against "New profile".
        if (kind === "create" && createName.length === 0)
            return items;

        const transformed = transformSearch(search).trim().replace(/\s+/g, " ");
        if (!transformed)
            return items;

        return fzfQuery(items, transformed);
    }

    function fzfQuery(items: list<var>, search: string): list<var> {
        if (useFuzzy) {
            const prepped = items.map(e => ({
                        _item: e,
                        name: Fuzzy.prepare(e.name)
                    }));
            return Fuzzy.go(search, prepped, {
                all: true,
                keys: ["name"],
                scoreFn: r => r[0].score
            }).map(r => r.obj._item);
        }
        const finder = new Fzf.Finder(items, {
            selector
        });
        return finder.find(search).sort((a, b) => {
            if (a.score === b.score)
                return a.item.name.length - b.item.name.length;
            return b.score - a.score;
        }).map(r => r.item);
    }

    function activate(item: var, list: AppList): void {
        switch (item.action) {
        case "hint":
            return;
        case "create":
            list.search.text = "";
            pickerFlow = "create";
            revision++;
            return;
        case "delete":
            list.search.text = "";
            pickerFlow = "delete";
            revision++;
            return;
        case "platform":
            list.search.text = "";
            pickerFlow = "list";
            revision++;
            createProc.command = ["cb-profile", "create", "--name", createName, "--platform", item.name];
            createProc.profileName = createName;
            createProc.running = true;
            createName = "";
            return;
        case "confirmDelete":
            list.search.text = "";
            pickerFlow = "list";
            revision++;
            deleteProc.command = ["cb-profile", "delete", item.name];
            deleteProc.profileName = item.name;
            deleteProc.running = true;
            return;
        case "launch":
            list.screenState.launcher = false;
            stopPicker();
            Launch.exec(["cb-profile", "launch", item.name]);
            return;
        }
    }

    // Called from Content.qml onAccepted in create mode while entering the name.
    function acceptCreate(text: string, list: AppList): void {
        const name = transformSearch(text);
        if (name.length === 0)
            return;

        if (!validateName(name)) {
            Toaster.toast(qsTr("CloakBrowser"), qsTr("Invalid or duplicate profile name: %1").arg(name), "error", Toast.Error);
            return;
        }

        createName = name;
        // Clear the typed name so the platform list isn't filtered by it.
        list.search.text = "";
        pickerFlow = "create";
        revision++;
    }

    function resetCreate(): void {
        createName = "";
    }

    list: []
    useFuzzy: GlobalConfig.launcher.useFuzzy.cloak

    Process {
        id: createProc

        property string profileName: ""

        stderr: StdioCollector {
            id: createStderr
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code === 0)
                Toaster.toast(qsTr("CloakBrowser"), qsTr("Created profile: %1").arg(profileName), "check", Toast.Success);
            else
                Toaster.toast(qsTr("CloakBrowser"), createStderr.text.trim() || qsTr("Failed to create profile"), "error", Toast.Error);
        }
    }

    Process {
        id: deleteProc

        property string profileName: ""

        stderr: StdioCollector {
            id: deleteStderr
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code === 0)
                Toaster.toast(qsTr("CloakBrowser"), qsTr("Deleted profile: %1").arg(profileName), "delete", Toast.Success);
            else
                Toaster.toast(qsTr("CloakBrowser"), deleteStderr.text.trim() || qsTr("Failed to delete profile"), "error", Toast.Error);
        }
    }

    FileView {
        id: profilesFile

        path: root.profilesPath
        watchChanges: true
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                const entries = Object.entries(data.profiles ?? {}).map(([name, info]) => ({
                            name,
                            platform: info.platform ?? "linux"
                        }));
                entries.sort((a, b) => a.name.localeCompare(b.name));
                root.profiles = entries;
            } catch (e) {
                console.warn("CloakProfiles: failed to parse profiles.json:", e);
                root.profiles = [];
            }
            root.revision++;
        }
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.profiles = [];
                root.revision++;
            }
        }
    }
}
