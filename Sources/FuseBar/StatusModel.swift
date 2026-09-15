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
    var detail: String {
        switch availability {
        case .unknown: return "电池状态未知"
        case .unavailable: return "无内置电池"
        case .available:
            let power = charging ? "正在充电" : externalPower ? (level >= 100 ? "已充满 · 已接电源" : "已接电源 · 未充电") : "电池供电"
            return "\(min(100, max(0, level)))% · \(power)"
        }
    }
}

struct WiFiStatus: Equatable {
    var connection: WiFiConnection = .unknown
    var name: String?
    var rssi: Int?
    var bars: Int {
        guard let rssi, rssi < 0 else { return 0 }
        return rssi >= -60 ? 3 : rssi >= -75 ? 2 : 1
    }
    var detail: String {
        switch connection {
        case .unknown: return "连接状态未知"
        case .unavailable: return "无 Wi-Fi 接口"
        case .off: return "Wi-Fi 已关闭"
        case .disconnected: return "未连接无线网络"
        case .connected: return name.map { "\($0) · 已连接" } ?? "已连接 · 网络名称受系统保护"
        }
    }
}

struct BluetoothStatus: Equatable {
    var state: BluetoothState = .permissionRequired
    var devices: [String] = []
    var detail: String {
        switch state {
        case .unknown: return "蓝牙状态未知"
        case .permissionRequired: return "需要授权读取连接状态"
        case .denied: return "蓝牙访问未获授权"
        case .unavailable: return "蓝牙不可用"
        case .off: return "蓝牙已关闭"
        case .on: return devices.isEmpty ? "已开启 · 未发现已连接的配对设备" : devices.joined(separator: "、")
        }
    }
}

struct SoundStatus: Equatable {
    var available = false
    var deviceName = "声音输出"
    var volume: Float?
    var muted: Bool?
    var canSetVolume = false
    var effectivelyMuted: Bool { muted == true || volume == 0 }
    var detail: String {
        guard available else { return "无可用输出设备" }
        if effectivelyMuted { return "\(deviceName) · 静音" }
        if let volume { return "\(deviceName) · \(Int((volume * 100).rounded()))%" }
        return "\(deviceName) · 设备控制音量"
    }
}

struct IndicatorPreferences: Equatable {
    var battery = true
    var wifi = true
    var bluetooth = true
    var sound = true
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

    func headline(_ preferences: IndicatorPreferences) -> String {
        switch badge(preferences) {
        case .critical: return "电量不足 10%，请连接电源"
        case .networkWarning: return "Wi-Fi 尚未连接"
        case .lowBattery: return "电量较低"
        case .charging: return "正在为下一程充电"
        case .muted: return "声音已静音"
        case .none: return preferences.anyEnabled ? "常用状态，一眼可见" : "所有图标指标已隐藏"
        }
    }

    func accessibilitySummary(_ p: IndicatorPreferences) -> String {
        var parts = ["FuseBar"]
        if p.battery { parts.append(battery.detail) }
        if p.wifi { parts.append("Wi-Fi：" + wifi.detail) }
        if p.bluetooth { parts.append("蓝牙：" + bluetooth.detail) }
        if p.sound { parts.append(sound.detail) }
        return parts.joined(separator: "。")
    }

    static let normal = StatusSnapshot(
        battery: BatteryStatus(availability: .available, level: 82),
        wifi: WiFiStatus(connection: .connected, name: "Home Wi-Fi", rssi: -52),
        bluetooth: BluetoothStatus(state: .on, devices: ["AirPods Pro"]),
        sound: SoundStatus(available: true, deviceName: "MacBook 扬声器", volume: 0.42, muted: false, canSetVolume: true)
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
        var weakSignal = normal; weakSignal.wifi.rssi = -82
        return [("日常", normal), ("充电", charging), ("低电量", low), ("严重低电", critical),
                ("Wi-Fi 断开", disconnected), ("无线关闭", off), ("静音", mute),
                ("多重异常", combined), ("桌面 Mac", desktop), ("尚未读取", StatusSnapshot()),
                ("Wi-Fi 中等", mediumSignal), ("Wi-Fi 较弱", weakSignal)]
    }
}
