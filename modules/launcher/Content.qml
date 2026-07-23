pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + search.anchors.bottomMargin

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: search.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight - search.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    SearchBar {
        id: search

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: qsTr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

        onAccepted: {
            // Create name entry works regardless of list contents: the text is
            // the new profile name, and the list may legitimately be empty.
            if (CloakProfiles.isCreateMode() && CloakProfiles.createName.length === 0) {
                CloakProfiles.acceptCreate(text, list.currentList);
                return;
            }
            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (CloakProfiles.pickerActive) {
                    CloakProfiles.activate(currentItem.modelData, list.currentList);
                } else if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                    if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    if (!CloakProfiles.pickerActive)
                        root.screenState.launcher = false;
                }
            }
        }

        Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
        Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

        Keys.onEscapePressed: {
            if (CloakProfiles.pickerActive) {
                search.text = "";
                CloakProfiles.stopPicker();
            } else {
                root.screenState.launcher = false;
            }
        }

        Keys.onPressed: event => {
            // Backspace on an empty search field leaves the picker.
            if (CloakProfiles.pickerActive && search.text.length === 0 && event.key === Qt.Key_Backspace) {
                CloakProfiles.stopPicker();
                event.accepted = true;
                return;
            }

            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }

        Component.onCompleted: {
            forceActiveFocus();
            // Apply a search requested while this launcher instance was closed
            // (e.g. `qs -c caelestia ipc call launcher openWithSearch`).
            // Only the active screen consumes; other monitors leave pendingSearch
            // for the correct instance.
            if (root.screenState !== ShellState.forActive())
                return;
            const pending = LauncherIpc.consume();
            if (pending.length > 0)
                search.text = pending;
        }

        Connections {
            function onLauncherChanged(): void {
                if (!root.screenState.launcher) {
                    search.text = "";
                    CloakProfiles.stopPicker();
                }
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }

        Connections {
            function onLauncherSearchRequested(text: string): void {
                if (root.screenState !== ShellState.forActive())
                    return;
                LauncherIpc.consume();
                search.text = text;
                root.screenState.launcher = true;
                search.forceActiveFocus();
            }

            target: LauncherIpc
        }

        Connections {
            // Clicking the CloakBrowser app entry asks us to clear the search
            // text so the picker list is unfiltered.
            function onPickerRequested(): void {
                search.text = "";
            }

            target: CloakProfiles
        }

    }
}
