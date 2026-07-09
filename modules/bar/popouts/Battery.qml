pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

Column {
    id: root

    spacing: Tokens.spacing.medium
    width: Tokens.sizes.bar.batteryWidth

    StyledText {
        text: UPower.displayDevice.isLaptopBattery ? qsTr("Remaining: %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : qsTr("No battery detected")
    }

    StyledText {
        function formatSeconds(s: int, fallback: string): string {
            const day = Math.floor(s / 86400);
            const hr = Math.floor(s / 3600) % 60;
            const min = Math.floor(s / 60) % 60;

            let comps = [];
            if (day > 0)
                comps.push(`${day} days`);
            if (hr > 0)
                comps.push(`${hr} hours`);
            if (min > 0)
                comps.push(`${min} mins`);

            return comps.join(", ") || fallback;
        }

        text: UPower.displayDevice.isLaptopBattery ? qsTr("Time %1: %2").arg(UPower.onBattery ? "remaining" : "until charged").arg(UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, "Calculating...") : formatSeconds(UPower.displayDevice.timeToFull, "Fully charged!")) : qsTr("Power mode: %1").arg(LecooPower.available ? LecooPower.modeInfo[LecooPower.currentMode]?.label ?? LecooPower.currentMode : "N/A")
    }

    // Lecoo power-mode selector — 4 modes with eco+ leftmost.
    // Replaces the upstream 3-mode PowerProfiles selector.
    // Bridge: LecooPower singleton → lecoo-power-mode get/set.
    StyledRect {
        id: profiles

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: modeRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: modeRow.implicitHeight + Tokens.padding.small

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        visible: LecooPower.available

        Row {
            id: modeRow

            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.largeIncreased

            Repeater {
                id: modeRepeater

                model: LecooPower.modes

                delegate: Item {
                    required property string modelData

                    implicitWidth: modeIcon.implicitWidth + Tokens.padding.small
                    implicitHeight: modeIcon.implicitHeight + Tokens.padding.small

                    readonly property bool isActive: profiles.visible && LecooPower.currentMode === modelData

                    StyledRect {
                        anchors.fill: parent
                        color: parent.isActive ? Colours.palette.m3primary : "transparent"
                        radius: Tokens.rounding.full

                        Behavior on color {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: parent.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: LecooPower.setMode(parent.modelData)
                    }

                    MaterialIcon {
                        id: modeIcon

                        anchors.centerIn: parent

                        text: LecooPower.modeInfo[parent.modelData]?.icon ?? "help"
                        color: parent.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        fill: parent.isActive ? 1 : 0
                        fontStyle: Tokens.font.icon.large

                        Behavior on fill {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }
                }
            }
        }
    }
}
