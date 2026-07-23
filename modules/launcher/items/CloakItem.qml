import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property var modelData
    required property var list

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: CloakProfiles.activate(root.modelData, root.list)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        Loader {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.font.icon.large.pointSize * 1.3
            height: width

            sourceComponent: glyphIcon
        }

        Component {
            id: glyphIcon

            StyledText {
                x: Math.round((icon.width - implicitWidth) / 2)
                y: Math.round((icon.height - implicitHeight) / 2)
                text: root.modelData?.glyph ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font.family: "CaskaydiaCove NF"
                font.pointSize: Tokens.font.mono.large.pointSize * 1.3
            }
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width
            implicitHeight: name.implicitHeight + desc.implicitHeight

            StyledText {
                id: name

                text: root.modelData?.name ?? ""
                font: Tokens.font.body.medium
            }

            StyledText {
                id: desc

                text: root.modelData?.desc ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3outline

                elide: Text.ElideRight
                width: root.width - icon.width - Tokens.rounding.extraLargeIncreased

                anchors.top: name.bottom
            }
        }
    }
}
