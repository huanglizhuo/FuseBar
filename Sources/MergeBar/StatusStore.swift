import AppKit
import Combine
import CoreBluetooth
import CoreLocation
import ServiceManagement

@MainActor
final class StatusStore: NSObject, ObservableObject, CBCentralManagerDelegate, CLLocationManagerDelegate {
    @Published private(set) var snapshot = StatusSnapshot()
    @Published var preferences: IndicatorPreferences {
        didSet {
            defaults.set(preferences.battery, forKey: "showBattery")
            defaults.set(preferences.wifi, forKey: "showWiFi")
            defaults.set(preferences.bluetooth, forKey: "showBluetooth")
            defaults.set(preferences.sound, forKey: "showSound")
        }
    }
    @Published var errorMessage: String?
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var updatedAt: Date?
    let defaults: UserDefaults
    private let worker = DispatchQueue(label: "com.mergebar.status", qos: .utility)
    private var central: CBCentralManager?
    private var location: CLLocationManager?
    private var timer: Timer?
    private var reading = false
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []
    private let demo: Bool

    init(defaults: UserDefaults = .standard, demo: Bool = false) {
        self.defaults = defaults
        self.demo = demo
        defaults.register(defaults: ["showBattery": true, "showWiFi": true, "showBluetooth": true, "showSound": true])
        preferences = IndicatorPreferences(battery: defaults.bool(forKey: "showBattery"), wifi: defaults.bool(forKey: "showWiFi"),
                                           bluetooth: defaults.bool(forKey: "showBluetooth"), sound: defaults.bool(forKey: "showSound"))
        super.init()
        if demo { snapshot = .normal; return }
        if CBManager.authorization == .allowedAlways { enableBluetooth() }
        refreshLoginStatus()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = true; self?.timer?.invalidate(); self?.timer = nil }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = false; self?.startTimer(); self?.refresh() }
        })
        startTimer()
        refresh()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func enableBluetooth() {
        guard !demo else { return }
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func requestNetworkName() {
        guard !demo else { return }
        let manager = location ?? CLLocationManager()
        location = manager
        manager.delegate = self
        switch manager.authorizationStatus {
        case .denied, .restricted:
            errorMessage = "网络名称需要定位授权。可在系统设置 → 隐私与安全性 → 定位服务中允许 MergeBar。"
        default:
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    private var bluetoothState: BluetoothState {
        switch CBManager.authorization {
        case .notDetermined: return .permissionRequired
        case .restricted, .denied: return .denied
        case .allowedAlways: break
        @unknown default: return .unknown
        }
        guard let central else { return .unknown }
        switch central.state {
        case .poweredOn: return .on
        case .poweredOff: return .off
        case .unauthorized: return .denied
        case .unsupported: return .unavailable
        default: return .unknown
        }
    }

    func refresh() {
        guard !demo, !reading, !sleeping else { return }
        // Recover if authorization was granted in System Settings while the app was running.
        if central == nil && CBManager.authorization == .allowedAlways { enableBluetooth() }
        reading = true
        let state = bluetoothState
        worker.async { [weak self] in
            let value = SystemReader.read(bluetoothState: state)
            Task { @MainActor in
                guard let self else { return }
                if self.snapshot != value { self.snapshot = value }
                self.updatedAt = Date()
                self.reading = false
            }
        }
    }

    func setVolume(_ value: Double) {
        guard !demo else { return }
        worker.async { [weak self] in
            let error = AudioDevice.setVolume(Float(value))
            Task { @MainActor in
                self?.errorMessage = error
                self?.refresh()
            }
        }
    }

    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { errorMessage = "无法更新登录启动：\(error.localizedDescription)" }
        refreshLoginStatus()
    }
}

enum SettingsDestination: String {
    case wifi = "com.apple.wifi-settings-extension"
    case bluetooth = "com.apple.BluetoothSettings"
    case battery = "com.apple.preference.battery"
    case sound = "com.apple.Sound-Settings.extension"
    case menuBar = "com.apple.ControlCenter-Settings.extension"
    case privacy = "com.apple.preference.security?Privacy_Bluetooth"

    @MainActor func open() {
        // Deep links vary across releases; fall back to opening the Settings application.
        if let url = URL(string: "x-apple.systempreferences:\(rawValue)"), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
