pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Network")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        Loader {
            Layout.fillWidth: true
            active: Nmcli.hasAvailableEthernet
            visible: active
            asynchronous: true

            sourceComponent: EthernetSection {
                nState: root.nState
                cappedWidth: root.cappedWidth
            }
        }

        ToggleRow {
            Layout.topMargin: Nmcli.hasAvailableEthernet ? Tokens.spacing.large : 0
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        NetworkList {
            Layout.bottomMargin: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? 0 : -parent.spacing
            nState: root.nState
            limit: GlobalConfig.nexus.maxNetworksShown

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // All networks button, only when > max networks
        ConnectedRect {
            Layout.fillWidth: true
            Layout.preferredHeight: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? showAllLayout.implicitHeight + Tokens.padding.medium * 2 : 0
            clip: true

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            StateLayer {
                onClicked: root.nState.openSubPage(4) // All networks sub-page
            }

            RowLayout {
                id: showAllLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "expand_content"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Show all networks (%1)").arg(Nmcli.networks.length)
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        // Saved networks button
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: savedNetworksLayout.implicitHeight + savedNetworksLayout.anchors.margins * 2

            StateLayer {
                onClicked: root.nState.openSubPage(5) // Saved networks sub-page
            }

            RowLayout {
                id: savedNetworksLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "bookmark"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                    fill: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Saved networks")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: addNetworkLayout.implicitHeight + addNetworkLayout.anchors.margins * 2
            last: true

            StateLayer {
                onClicked: root.nState.openSubPage(2) // Add network sub-page
            }

            RowLayout {
                id: addNetworkLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased

                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "add"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Add network")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
