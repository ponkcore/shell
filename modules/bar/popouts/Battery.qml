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
            const hr = Math.floor(s / 3600) % 24;
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
    // Uses the upstream sliding-indicator pattern with AnchorChanges.
    // Bridge: LecooPower singleton → lecoo-power-mode get/set.
    StyledRect {
        id: profiles

        property string currentIcon: {
            const mode = LecooPower.currentMode;
            if (mode === "eco+")
                return "battery_saver";
            if (mode === "eco")
                return "energy_savings_leaf";
            if (mode === "balanced")
                return "balance";
            if (mode === "performance")
                return "rocket_launch";
            return "";
        }

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: ecoPlusItem.implicitWidth + ecoItem.implicitWidth + balancedItem.implicitWidth + perfItem.implicitWidth + Tokens.padding.extraSmall * 2 + Tokens.spacing.largeIncreased * 3
        implicitHeight: Math.max(ecoPlusItem.implicitHeight, ecoItem.implicitHeight, balancedItem.implicitHeight, perfItem.implicitHeight) + Tokens.padding.small

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        visible: LecooPower.available

        StyledRect {
            id: indicator

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full
            state: profiles.currentIcon

            states: [
                State {
                    name: "battery_saver"

                    Fill {
                        item: ecoPlusItem
                    }
                },
                State {
                    name: "energy_savings_leaf"

                    Fill {
                        item: ecoItem
                    }
                },
                State {
                    name: "balance"

                    Fill {
                        item: balancedItem
                    }
                },
                State {
                    name: "rocket_launch"

                    Fill {
                        item: perfItem
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }
        }

        Profile {
            id: ecoPlusItem

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.extraSmall

            mode: "eco+"
            icon: "battery_saver"
        }

        Profile {
            id: ecoItem

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: ecoPlusItem.right
            anchors.leftMargin: Tokens.spacing.largeIncreased

            mode: "eco"
            icon: "energy_savings_leaf"
        }

        Profile {
            id: balancedItem

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: ecoItem.right
            anchors.leftMargin: Tokens.spacing.largeIncreased

            mode: "balanced"
            icon: "balance"
        }

        Profile {
            id: perfItem

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.extraSmall

            mode: "performance"
            icon: "rocket_launch"
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string mode
        required property string icon

        readonly property bool isActive: profiles.visible && LecooPower.currentMode === mode

        implicitWidth: iconEl.implicitWidth + Tokens.padding.small
        implicitHeight: iconEl.implicitHeight + Tokens.padding.small

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: parent.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: LecooPower.setMode(parent.mode)
        }

        MaterialIcon {
            id: iconEl

            anchors.centerIn: parent

            text: parent.icon
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
