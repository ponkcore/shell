pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Charge-limit selector card — horizontal row of 5 buttons for
// FlexiCharger modes (full/high/balanced/lifespan/desk).
// Bridge: LecooCharge singleton → lecoo-charge-mode get/set.
// Placed between Quick Toggles and Recordings per user spec.

StyledRect {
    id: root

    readonly property real nonAnimHeight: layout.implicitHeight + Tokens.padding.extraLargeIncreased

    Layout.fillWidth: true
    implicitHeight: nonAnimHeight

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    visible: LecooCharge.available

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: Colours.palette.m3tertiaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "battery_lock"
                    color: Colours.palette.m3onTertiaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Charge Limit")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: LecooCharge.available ? qsTr("Current: %1").arg(LecooCharge.modeInfo[LecooCharge.currentMode]?.label ?? LecooCharge.currentMode) : qsTr("Unavailable")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }

        ButtonRow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: LecooCharge.modes

                delegate: TextButton {
                    required property string modelData

                    fillWidth: true
                    isToggle: true
                    checked: LecooCharge.currentMode === modelData
                    text: LecooCharge.modeInfo[modelData]?.label ?? modelData
                    onClicked: LecooCharge.setMode(modelData)
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
