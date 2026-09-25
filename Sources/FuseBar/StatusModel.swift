import Foundation

enum Availability: Equatable { case unknown, unavailable, available }
enum WiFiConnection: Equatable { case unknown, unavailable, off, disconnected, connected }
enum BluetoothState: Equatable { case unknown, permissionRequired, denied, unavailable, off, on }

struct BatteryStatus: Equatable {
    var availability: Availability = .unknown
    var level: Int = 0
    var charging = false
    var externalPower = false
    var fraction: Double { Double(min(100, max(0, level))) / 100 }
    var critical: Bool { availability == .available && level < 10 && !externalPower }
    var low: Bool { availability == .available && level < 20 && !externalPower }
    /// macOS tints its battery indicator green while charging and red only at the
    /// critical threshold; merely low batteries keep the plain label color.
    enum SystemTint: Equatable { case none, charging, critical }
    var systemTint: SystemTint {
        guard availability == .available else { return .none }
        if charging { return .charging }
        if critical { return .critical }
        return .none
    }
    var detail: String {
        switch availability {
        case .unknown: return L("电池状态未知")
        case .unavailable: return L("无内置电池")
        case .available:
            let power = charging ? L("正在充电") : externalPower ? (level >= 100 ? L("已充满 · 已接电源") : L("已接电源 · 未充电")) : L("电池供电")
            return "\(min(100, max(0, level)))% · \(power)"
        }
    }
}

struct WiFiStatus: Equatable {
    var connection: WiFiConnection = .unknown
    var name: String?
    var rssi: Int?
    // Network.framework marks Personal Hotspot-class Wi-Fi paths as expensive.
    // This is a network-cost signal, not proof of the phone manufacturer.
    var hotspotStyle = false
    var bars: Int { rssi.map(Self.bars(forRSSI:)) ?? 0 }
    /// Signal bars from RSSI, shared by status reads and nearby-network rows.
    static func bars(forRSSI rssi: Int) -> Int {
        guard rssi < 0 else { return 0 }
        return rssi >= -60 ? 3 : rssi >= -75 ? 2 : 1
    }
    var detail: String {
        switch connection {
        case .unknown: return L("连接状态未知")
        case .unavailable: return L("无 Wi-Fi 接口")
        case .off: return L("Wi-Fi 已关闭")
        case .disconnected: return L("未连接无线网络")
        case .connected:
            if hotspotStyle { return (name.map { "\($0) · " } ?? "") + L("热点 / 按流量计费网络 · 已连接") }
            return name.map { L("%@ · 已连接", $0) } ?? L("已连接 · 网络名称暂不可用")
        }
    }
}

struct BluetoothStatus: Equatable {
    var state: BluetoothState = .permissionRequired
    var devices: [String] = []
    var detail: String {
        switch state {
        case .unknown: return L("蓝牙状态未知")
        case .permissionRequired: return L("需要授权读取连接状态")
        case .denied: return L("蓝牙访问未获授权")
        case .unavailable: return L("蓝牙不可用")
        case .off: return L("蓝牙已关闭")
        case .on: return devices.isEmpty ? L("已开启 · 未发现已连接的配对设备") : ListFormatter.localizedString(byJoining: devices)
        }
    }
}

/// Fallback output-device name shared by reads that cannot resolve a device name.
let defaultAudioDeviceName = L("声音输出")

struct SoundStatus: Equatable {
    var available = false
    var deviceName = defaultAudioDeviceName
    var volume: Float?
    var muted: Bool?
    var canSetVolume = false
    var canSetMute = false
    var deviceUID: String?
    var effectivelyMuted: Bool { muted == true || volume == 0 }
    var volumeDots: Int? {
        guard available, let volume, volume.isFinite else { return nil }
        return Int(ceil(Double(min(1, max(0, volume))) * 4))
    }
    var detail: String {
        guard available else { return L("无可用输出设备") }
        if effectivelyMuted { return L("%@ · 静音", deviceName) }
        if let volume, volume.isFinite { return "\(deviceName) · \(volumePercent(Double(volume)))%" }
        return L("%@ · 设备控制音量", deviceName)
    }
}

enum CenterIndicator: String, CaseIterable { case network, sound }

/// Volume as a whole percentage for display, shared by the orb, rows and panels.
func volumePercent(_ volume: Double) -> Int {
    Int((min(1, max(0, volume)) * 100).rounded())
}

/// Locale-aware ascending comparison for display names, shared by device and app lists.
func nameIsBefore(_ lhs: String, _ rhs: String) -> Bool {
    lhs.localizedStandardCompare(rhs) == .orderedAscending
}

/// What the bottom slot of the orb shows: the default alert/dot pipeline or a
/// persistent numeric readout of one metric.
enum BottomIndicator: String, CaseIterable { case status, batteryLevel, volumeLevel }

struct IndicatorPreferences: Equatable {
    var battery = true
    var wifi = true
    var bluetooth = true
    var sound = true
    var center: CenterIndicator = .network
    var bottomIndicator: BottomIndicator = .status
    var centerEnabled: Bool { center == .network ? wifi : sound }
    var anyEnabled: Bool { battery || wifi || sound }
}

enum OrbBadge: Equatable { case none, critical, networkWarning, lowBattery, charging, muted }

struct StatusSnapshot: Equatable {
    var battery = BatteryStatus()
    var wifi = WiFiStatus()
    var bluetooth = BluetoothStatus()
    var sound = SoundStatus()

    func badge(_ preferences: IndicatorPreferences) -> OrbBadge {
        if preferences.battery && battery.critical { return .critical }
        if preferences.wifi && wifi.connection == .disconnected { return .networkWarning }
        if preferences.battery && battery.low { return .lowBattery }
        if preferences.battery && battery.availability == .available && battery.charging { return .charging }
        if preferences.sound && sound.effectivelyMuted { return .muted }
        return .none
    }

    func volumeDots(_ preferences: IndicatorPreferences) -> Int? {
        guard preferences.sound, badge(preferences) == .none else { return nil }
        return sound.volumeDots
    }

    /// The persistent numeric readout chosen for the bottom slot; nil keeps the
    /// default alert/dot pipeline, including when the chosen metric is unavailable.
    func bottomNumber(_ preferences: IndicatorPreferences) -> String? {
        switch preferences.bottomIndicator {
        case .status: return nil
        case .batteryLevel:
            guard preferences.battery, battery.availability == .available else { return nil }
            return String(min(100, max(0, battery.level)))
        case .volumeLevel:
            guard preferences.sound, sound.available, let volume = sound.volume, volume.isFinite else { return nil }
            return String(volumePercent(Double(volume)))
        }
    }

    func headline(_ preferences: IndicatorPreferences) -> String {
        switch badge(preferences) {
        case .critical: return L("电量不足 10%，请连接电源")
        case .networkWarning: return L("Wi-Fi 尚未连接")
        case .lowBattery: return L("电量较低")
        case .charging: return L("正在为下一程充电")
        case .muted: return L("声音已静音")
        case .none: return preferences.anyEnabled ? L("常用状态，一眼可见") : L("所有图标指标已隐藏")
        }
    }

    func accessibilitySummary(_ p: IndicatorPreferences) -> String {
        var parts = ["FuseBar"]
        if p.battery { parts.append(battery.detail) }
        if p.wifi { parts.append("Wi-Fi: " + wifi.detail) }
        if p.bluetooth { parts.append(L("蓝牙：") + bluetooth.detail) }
        if p.sound { parts.append(sound.detail) }
        return parts.joined(separator: ". ")
    }

    static let normal = StatusSnapshot(
        battery: BatteryStatus(availability: .available, level: 82),
        wifi: WiFiStatus(connection: .connected, name: "Home Wi-Fi", rssi: -52),
        bluetooth: BluetoothStatus(state: .on, devices: ["AirPods Pro"]),
        sound: SoundStatus(available: true, deviceName: L("MacBook 扬声器"), volume: 0.42, muted: false, canSetVolume: true)
    )

    static var scenarios: [(String, StatusSnapshot)] {
        var charging = normal; charging.battery.charging = true; charging.battery.externalPower = true
        var low = normal; low.battery.level = 16
        var critical = normal; critical.battery.level = 7
        var disconnected = normal; disconnected.wifi.connection = .disconnected
        var off = normal; off.wifi.connection = .off; off.bluetooth.state = .off; off.bluetooth.devices = []
        var mute = normal; mute.sound.muted = true
        var combined = critical; combined.wifi.connection = .disconnected; combined.sound.muted = true
        var desktop = normal; desktop.battery.availability = .unavailable
        var mediumSignal = normal; mediumSignal.wifi.rssi = -68
        var hotspot = normal; hotspot.wifi.hotspotStyle = true; hotspot.wifi.name = "Personal Hotspot"
        var weakSignal = normal; weakSignal.wifi.rssi = -82
        return [(L("日常"), normal), (L("充电"), charging), (L("低电量"), low), (L("严重低电"), critical),
                (L("Wi-Fi 断开"), disconnected), (L("无线关闭"), off), (L("静音"), mute),
                (L("多重异常"), combined), (L("桌面 Mac"), desktop), (L("尚未读取"), StatusSnapshot()),
                (L("Wi-Fi 中等"), mediumSignal), (L("Wi-Fi 较弱"), weakSignal), (L("个人热点"), hotspot)]
    }
}


/// Authorization and an unavailable SSID are independent states.
enum NetworkNameAccess: Equatable {
    case notRequested, allowed, blocked, unknown
}

extension WiFiStatus {
    func shouldOfferNameAuthorization(_ access: NetworkNameAccess) -> Bool {
        connection == .connected && name == nil && (access == .notRequested || access == .blocked)
    }
}
