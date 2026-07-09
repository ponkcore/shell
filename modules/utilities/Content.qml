import "cards"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property var props
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    // Order per user spec: IdleInhibit, Quick Toggles, Charge Limit,
    // Recordings. Charge-limit row sits between toggles and recordings.
    readonly property real nonAnimHeight: idleInhibit.nonAnimHeight + toggles.implicitHeight + chargeLimit.nonAnimHeight + record.nonAnimHeight + layout.spacing * 3

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        IdleInhibit {
            id: idleInhibit

            objectName: "utilitiesKeepAwake"
        }

        Toggles {
            id: toggles

            objectName: "utilitiesQuickToggles"

            screenState: root.screenState
            popouts: root.popouts
        }

        ChargeLimit {
            id: chargeLimit

            objectName: "utilitiesChargeLimit"
        }

        Record {
            id: record

            objectName: "utilitiesScreenRecorder"

            props: root.props
            screenState: root.screenState
            z: 1
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
