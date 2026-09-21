import Foundation
import CoreBluetooth
import IOBluetooth
import CoreAudio

/// CoreAudio reports the user-assigned name of connected Bluetooth audio devices.
/// Only accept the observed, exact address:output UID form; never match by name
/// or a partial address. Other UID formats retain the Bluetooth-provided name.
final class BluetoothDeviceNames: @unchecked Sendable {
    static let shared = BluetoothDeviceNames(defaults: .standard)
    private let lock = NSLock()
    private let defaults: UserDefaults
    private var names: [String: String]
    private static let key = "bluetoothAudioDisplayNames"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        names = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    }

    static func addressKey(_ address: String) -> String? {
        let parts = address.lowercased().replacingOccurrences(of: ":", with: "-").split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy { $0.isASCII && $0.isHexDigit } }) else { return nil }
        return parts.joined(separator: "-")
    }

    static func audioAddress(_ output: AudioOutput) -> String? {
        guard [kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE].contains(output.transport),
              output.id.lowercased().hasSuffix(":output") else { return nil }
        return addressKey(String(output.id.dropLast(7)))
    }

    func resolve(addresses: [String], outputs: [AudioOutput]) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        let allowed = Set(addresses.compactMap(Self.addressKey))
        var updated = names.filter { allowed.contains($0.key) }
        let candidates = Dictionary(grouping: outputs.compactMap { output -> (String, String)? in
            guard let key = Self.audioAddress(output), allowed.contains(key),
                  !output.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return (key, output.name)
        }, by: { $0.0 })
        for (key, values) in candidates {
            let distinct = Set(values.map(\.1))
            if distinct.count == 1 { updated[key] = distinct.first }
        }
        if updated != names {
            names = updated
            defaults.set(updated, forKey: Self.key)
        }
        return updated
    }
}

protocol BluetoothDeviceControlling: Sendable {
    func read() -> [PairedBluetoothDevice]?
    func setConnected(address: String, connected: Bool) -> String?
}

struct SystemBluetoothDeviceClient: BluetoothDeviceControlling {
    private static let commandLock = NSLock()
    func read() -> [PairedBluetoothDevice]? {
        guard CBManager.authorization == .allowedAlways,
              let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return nil }
        let aliases = BluetoothDeviceNames.shared.resolve(addresses: paired.compactMap(\.addressString), outputs: AudioDevice.outputs())
        return paired.compactMap { device in
            guard let address = device.addressString else { return nil }
            let name = BluetoothDeviceNames.addressKey(address).flatMap { aliases[$0] } ?? device.name ?? L("蓝牙设备")
            return PairedBluetoothDevice(id: address, name: name, connected: device.isConnected(),
                                         symbol: BluetoothPanelStore.symbol(major: device.deviceClassMajor, minor: device.deviceClassMinor),
                                         isAudioDevice: device.deviceClassMajor == 4 || BluetoothDeviceNames.addressKey(address).flatMap { aliases[$0] } != nil)
        }.sorted {
            if $0.connected != $1.connected { return $0.connected }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func setConnected(address: String, connected: Bool) -> String? {
        Self.commandLock.lock()
        defer { Self.commandLock.unlock() }
        guard CBManager.authorization == .allowedAlways else { return L("蓝牙访问未获授权") }
        guard let key = BluetoothDeviceNames.addressKey(address),
              let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice],
              let device = paired.first(where: { $0.addressString.flatMap(BluetoothDeviceNames.addressKey) == key }),
              device.isPaired() else { return L("设备已不在配对列表中，请刷新后重试。") }
        // Use the requested final state, never toggle a possibly stale UI value.
        guard device.isConnected() != connected else { return nil }
        let result = connected
            ? device.openConnection(nil, withPageTimeout: 8_000, authenticationRequired: true)
            : device.closeConnection()
        // A successful command is not enough: allow the daemon to settle and read back.
        for _ in 0..<20 {
            if device.isConnected() == connected { return nil }
            if result != kIOReturnSuccess { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return connected
            ? L("连接未完成，请确认设备已开机且在附近，然后重试。")
            : L("未能断开设备，请重试。")
    }
}
