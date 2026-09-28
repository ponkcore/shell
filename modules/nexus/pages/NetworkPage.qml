pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
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
        RowButton {
            Layout.preferredHeight: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? implicitHeight : 0
            clip: true

            icon: "expand_content"
            text: qsTr("Show all networks (%1)").arg(Nmcli.networks.length)
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(4) // All networks sub-page

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Saved networks button
        RowButton {
            icon: "bookmark"
            text: qsTr("Saved networks")
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(5) // Saved networks sub-page
        }

        RowButton {
            last: true
            icon: "add"
            text: qsTr("Add network")
            disabled: !Nmcli.wifiEnabled
            onClicked: root.nState.openSubPage(2) // Add network sub-page
        }
    }
}
