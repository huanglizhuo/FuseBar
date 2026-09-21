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

    static func wifi(path: WiFiPathState? = nil) -> WiFiStatus {
        guard let interface = CWWiFiClient.shared().interface() else {
            if path?.connected == true { return resolveWiFi(mode: .none, name: nil, rssi: 0, path: path) }
            return WiFiStatus(connection: .unavailable)
        }
        guard interface.powerOn() || path?.connected == true else { return WiFiStatus(connection: .off) }
        return resolveWiFi(mode: interface.interfaceMode(), name: interface.ssid(),
                           rssi: interface.rssiValue(), path: path)
    }

    static func resolveWiFi(mode: CWInterfaceMode, name: String?, rssi: Int,
                            path: WiFiPathState?) -> WiFiStatus {
        // CoreWLAN .none can mean a read error. A satisfied Wi-Fi-only path is
        // positive evidence of connectivity even when CoreWLAN cannot report association.
        if mode == .station || path?.connected == true {
            return WiFiStatus(connection: .connected, name: name, rssi: rssi < 0 ? rssi : nil,
                              hotspotStyle: path?.connected == true && path?.expensive == true)
        }
        if mode == .none, path?.connected == false { return WiFiStatus(connection: .disconnected) }
        return WiFiStatus(connection: .unknown)
    }

    static func bluetooth(state: BluetoothState) -> BluetoothStatus {
        guard state == .on else { return BluetoothStatus(state: state) }
        guard let paired = SystemBluetoothDeviceClient().read() else {
            return BluetoothStatus(state: .unknown)
        }
        return BluetoothStatus(state: .on, devices: paired.filter(\.connected).map(\.name).sorted())
    }

    static func read(bluetoothState: BluetoothState, wifiPath: WiFiPathState? = nil) -> StatusSnapshot {
        StatusSnapshot(battery: battery(), wifi: wifi(path: wifiPath), bluetooth: bluetooth(state: bluetoothState), sound: AudioDevice.read())
    }
}

/// A value captured from the Wi-Fi-only NWPathMonitor; nil means not sampled yet.
struct WiFiPathState: Equatable {
    var connected: Bool
    var expensive: Bool
}
