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

        property string current: LecooPower.available ? LecooPower.currentMode : "balanced"

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: {
            let w = 0
            for (let i = 0; i < modeRepeater.count; i++)
                w += modeRepeater.itemAt(i).implicitWidth
            w += Tokens.spacing.largeIncreased * (modeRepeater.count - 1) + Tokens.padding.medium * 2
            return w
        }
        implicitHeight: modeRepeater.count > 0 ? modeRepeater.itemAt(0).implicitHeight + Tokens.padding.small : 0

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        visible: LecooPower.available

        StyledRect {
            id: indicator

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full

            x: {
                const item = modeRepeater.itemAt(indicator.currentIndex)
                return item ? item.x : 0
            }
            y: {
                const item = modeRepeater.itemAt(indicator.currentIndex)
                return item ? item.y : 0
            }
            width: {
                const item = modeRepeater.itemAt(indicator.currentIndex)
                return item ? item.width : 0
            }
            height: {
                const item = modeRepeater.itemAt(indicator.currentIndex)
                return item ? item.height : 0
            }

            property int currentIndex: {
                const modes = LecooPower.modes
                for (let i = 0; i < modes.length; i++) {
                    if (modes[i] === profiles.current)
                        return i
                }
                return 1 // fallback to eco
            }

            Behavior on x { Anim { type: Anim.DefaultSpatial } }
            Behavior on y { Anim { type: Anim.DefaultSpatial } }
            Behavior on width { Anim { type: Anim.DefaultSpatial } }
            Behavior on height { Anim { type: Anim.DefaultSpatial } }
        }

        Row {
            id: modeRow

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.largeIncreased

            Repeater {
                id: modeRepeater

                model: LecooPower.modes

                delegate: Item {
                    required property string modelData
                    required property int index

                    implicitWidth: modeIcon.implicitWidth + Tokens.padding.small
                    implicitHeight: modeIcon.implicitHeight + Tokens.padding.small

                    StateLayer {
                        radius: Tokens.rounding.full
                        color: profiles.current === parent.modelData ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: LecooPower.setMode(parent.modelData)
                    }

                    MaterialIcon {
                        id: modeIcon

                        anchors.centerIn: parent

                        text: LecooPower.modeInfo[parent.modelData]?.icon ?? "help"
                        color: profiles.current === parent.modelData ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        fill: profiles.current === parent.modelData ? 1 : 0
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
