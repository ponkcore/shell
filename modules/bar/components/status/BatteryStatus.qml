import QtQuick
import Quickshell.Services.UPower
import qs.components
import qs.services
import qs.utils

MaterialIcon {
    required property color colour

    animate: true
    // Battery icon — always shows battery percentage/charging state.
    // Power mode selection is in the battery popout, not the bar icon.
    text: {
        if (!UPower.displayDevice.isLaptopBattery)
            return "battery_full";
        return Icons.getBatteryIcon(UPower.displayDevice.percentage, [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state));
    }
    color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? colour : Colours.palette.m3error
    fill: 1
}
