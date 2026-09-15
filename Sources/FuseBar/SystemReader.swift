import CoreWLAN
import IOKit.ps
import IOBluetooth

enum SystemReader {
    static func battery() -> BatteryStatus {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatteryStatus()
        }
        for source in sources {
            guard let details = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  details[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            guard let current = details[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = details[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { return BatteryStatus() }
            return BatteryStatus(availability: .available,
                                 level: min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded()))),
                                 charging: details[kIOPSIsChargingKey] as? Bool ?? false,
                                 externalPower: details[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return BatteryStatus(availability: .unavailable)
    }

    static func wifi() -> WiFiStatus {
        guard let interface = CWWiFiClient.shared().interface() else { return WiFiStatus(connection: .unavailable) }
        guard interface.powerOn() else { return WiFiStatus(connection: .off) }
        // SSID may be redacted without location permission. Station mode denotes association.
        let mode = interface.interfaceMode()
        if mode == .station {
            let rssi = interface.rssiValue()
            return WiFiStatus(connection: .connected, name: interface.ssid(), rssi: rssi < 0 ? rssi : nil)
        }
        if mode == .none { return WiFiStatus(connection: .disconnected) }
        return WiFiStatus(connection: .unknown)
    }

    static func bluetooth(state: BluetoothState) -> BluetoothStatus {
        guard state == .on else { return BluetoothStatus(state: state) }
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return BluetoothStatus(state: .unknown)
        }
        let names = paired.filter { $0.isConnected() }.map { $0.name ?? "已连接的蓝牙设备" }.sorted()
        return BluetoothStatus(state: .on, devices: names)
    }

    static func read(bluetoothState: BluetoothState) -> StatusSnapshot {
        StatusSnapshot(battery: battery(), wifi: wifi(), bluetooth: bluetooth(state: bluetoothState), sound: AudioDevice.read())
    }
}
