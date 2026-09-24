import AppKit
import Combine
import CoreAudio
import CoreBluetooth
import CoreLocation
import Network
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
            defaults.set(preferences.center.rawValue, forKey: "centerIndicator")
            defaults.set(preferences.bottomIndicator.rawValue, forKey: "bottomIndicator")
        }
    }
    @Published private(set) var networkNameAccess: NetworkNameAccess = .unknown
    /// True while the CoreLocation consent alert for network names awaits an answer.
    private(set) var networkNamePermissionInFlight = false
    @Published var errorMessage: String?
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var updatedAt: Date?
    @Published private(set) var audioSelectionID: String?
    @Published private(set) var audioOutputs: [AudioOutput] = []
    @Published private(set) var audioBusy = false
    let defaults: UserDefaults
    private let worker = DispatchQueue(label: "com.fusebar.status", qos: .utility)
    private var audioRefreshPending = false
    private let audioWorker = DispatchQueue(label: "com.fusebar.audio", qos: .userInitiated)
    private let connectionWorker = DispatchQueue(label: "com.fusebar.audio-connection", qos: .userInitiated)
    private var soundReading = false
    private var soundRefreshPending = false
    private lazy var volumeWriter = LatestVolumeWriter(queue: audioWorker) { [weak self] error in
        self?.errorMessage = error
        self?.refreshSound()
    }
    private var audioMonitor: AudioChangeMonitor?
    private var soundRevision = 0
    private var central: CBCentralManager?
    private var location: CLLocationManager?
    private var wifiMonitor: NWPathMonitor?
    private var wifiPath: WiFiPathState?
    private var timer: Timer?
    private var reading = false
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []
    private let demo: Bool

    init(defaults: UserDefaults = .standard, demo: Bool = false) {
        self.defaults = defaults
        self.demo = demo
        defaults.register(defaults: ["showBattery": true, "showWiFi": true, "showBluetooth": true, "showSound": true,
                                     "bottomIndicator": BottomIndicator.status.rawValue])
        preferences = IndicatorPreferences(battery: defaults.bool(forKey: "showBattery"), wifi: defaults.bool(forKey: "showWiFi"),
                                           bluetooth: defaults.bool(forKey: "showBluetooth"), sound: defaults.bool(forKey: "showSound"),
                                           center: CenterIndicator(rawValue: defaults.string(forKey: "centerIndicator") ?? "") ?? .network,
                                           bottomIndicator: BottomIndicator(rawValue: defaults.string(forKey: "bottomIndicator") ?? "") ?? .status)
        super.init()
        if demo {
            snapshot = .normal
            audioOutputs = [AudioOutput(id: "built-in", name: snapshot.sound.deviceName, selected: true, transport: kAudioDeviceTransportTypeBuiltIn),
                            AudioOutput(id: "headphones", name: "Studio Headphones", selected: false, transport: kAudioDeviceTransportTypeBluetooth),
                            AudioOutput(id: "display", name: "Studio Display", selected: false, transport: kAudioDeviceTransportTypeHDMI)]
            return
        }
        let locationManager = CLLocationManager()
        location = locationManager
        locationManager.delegate = self
        updateNetworkNameAccess()
        if CBManager.authorization == .allowedAlways { enableBluetooth() }
        refreshLoginStatus()
        audioMonitor = AudioChangeMonitor(changed: { [weak self] in self?.refreshSound() }, outputsChanged: { [weak self] in self?.refreshAudioOutputs() })
        audioMonitor?.start()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = true; self?.audioMonitor?.stop(); self?.timer?.invalidate(); self?.timer = nil }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = false; self?.audioMonitor?.start(); self?.startTimer(); self?.refresh() }
        })
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        wifiMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let value = WiFiPathState(connected: path.status == .satisfied && path.usesInterfaceType(.wifi),
                                     expensive: path.isExpensive)
            Task { @MainActor in
                guard let self else { return }
                self.wifiPath = value
                self.refresh()
            }
        }
        monitor.start(queue: worker)
        startTimer()
        refresh()
    }

    func stop() {
        audioMonitor?.stop(); audioMonitor = nil
        volumeWriter.cancelPending()
        wifiMonitor?.cancel(); wifiMonitor = nil
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
        updateNetworkNameAccess()
        switch manager.authorizationStatus {
        case .denied, .restricted:
            errorMessage = L("网络名称需要定位授权。可在系统设置 → 隐私与安全性 → 定位服务中允许 FuseBar。")
        case .authorizedAlways:
            refresh()
        default:
            networkNamePermissionInFlight = true
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.networkNamePermissionInFlight = false
            self?.updateNetworkNameAccess()
            self?.refresh()
        }
    }

    private func updateNetworkNameAccess() {
        guard let location else { return }
        let access: NetworkNameAccess
        switch location.authorizationStatus {
        case .authorizedAlways: access = .allowed
        case .notDetermined: access = .notRequested
        case .denied, .restricted: access = .blocked
        @unknown default: access = .unknown
        }
        if networkNameAccess != access { networkNameAccess = access }
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
        updateNetworkNameAccess()
        guard !demo, !reading, !sleeping else { return }
        // Recover if authorization was granted in System Settings while the app was running.
        if central == nil && CBManager.authorization == .allowedAlways { enableBluetooth() }
        reading = true
        let state = bluetoothState
        let path = wifiPath
        let revision = soundRevision
        worker.async { [weak self] in
            let value = SystemReader.read(bluetoothState: state, wifiPath: path)
            Task { @MainActor in
                guard let self else { return }
                var current = value
                if self.soundRevision != revision { current.sound = self.snapshot.sound }
                if self.snapshot != current { self.snapshot = current }
                self.updatedAt = Date()
                self.reading = false
                // A first path update can arrive while the initial hardware read is in flight.
                if self.wifiPath != path { self.refresh() }
            }
        }
    }

    func setVolume(_ value: Double) {
        guard !demo, !audioBusy, value.isFinite else { return }
        errorMessage = nil
        soundRevision += 1
        volumeWriter.submit(VolumeWriteRequest(value: min(1, max(0, value)), deviceUID: snapshot.sound.deviceUID))
    }

    private func refreshSound() {
        guard !demo, !sleeping else { return }
        guard !soundReading else { soundRefreshPending = true; return }
        soundReading = true
        soundRevision += 1
        let revision = soundRevision
        audioWorker.async { [weak self] in
            let sound = AudioDevice.read()
            Task { @MainActor in
                guard let self else { return }
                self.soundReading = false
                if self.soundRevision == revision, self.snapshot.sound != sound { self.snapshot.sound = sound }
                if self.soundRefreshPending {
                    self.soundRefreshPending = false
                    self.refreshSound()
                }
            }
        }
    }

    func setMuted(_ muted: Bool) {
        guard !demo, !audioBusy else { return }
        audioBusy = true
        audioWorker.async { [weak self] in
            let error = AudioDevice.setMuted(muted)
            Task { @MainActor in
                self?.finishAudioOperation()
                self?.errorMessage = error
                self?.refreshSound()
            }
        }
    }

    func refreshAudioOutputs() {
        guard !demo else { return }
        guard !audioBusy else { audioRefreshPending = true; return }
        audioBusy = true
        audioWorker.async { [weak self] in
            let outputs = AudioOutput.choices(outputs: AudioDevice.outputs(), paired: SystemBluetoothDeviceClient().read() ?? [])
            Task { @MainActor in
                self?.audioOutputs = outputs
                self?.finishAudioOperation()
            }
        }
    }

    func selectAudioOutput(_ output: AudioOutput) {
        guard !demo, !audioBusy, !output.selected else { return }
        audioBusy = true
        audioSelectionID = output.id
        errorMessage = nil
        volumeWriter.cancelPending()
        connectionWorker.async { [weak self] in
            let error: String?
            if let address = output.bluetoothAddress {
                error = BluetoothAudioConnection.select(address: address)
            } else {
                error = AudioDevice.selectOutput(uid: output.id)
            }
            let outputs = AudioOutput.choices(outputs: AudioDevice.outputs(), paired: SystemBluetoothDeviceClient().read() ?? [])
            Task { @MainActor in
                self?.audioOutputs = outputs
                self?.finishAudioOperation()
                self?.errorMessage = error
                self?.refreshSound()
            }
        }
    }

    private func finishAudioOperation() {
        audioBusy = false
        audioSelectionID = nil
        if audioRefreshPending {
            audioRefreshPending = false
            refreshAudioOutputs()
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
        } catch { errorMessage = L("无法更新登录启动：%@", error.localizedDescription) }
        refreshLoginStatus()
    }
}

enum SettingsDestination: String {
    case wifi = "com.apple.wifi-settings-extension"
    case bluetooth = "com.apple.BluetoothSettings"
    case battery = "com.apple.preference.battery"
    case sound = "com.apple.Sound-Settings.extension"
    case menuBar = "com.apple.ControlCenter-Settings.extension"
    case displays = "com.apple.Displays-Settings.extension"
    case focus = "com.apple.Focus-Settings.extension"
    case airDrop = "com.apple.AirDrop-Handoff-Settings.extension"
    case desktop = "com.apple.Desktop-Settings.extension"
    case keyboard = "com.apple.Keyboard-Settings.extension"
    case accessibility = "com.apple.Accessibility-Settings.extension"
    case notifications = "com.apple.Notifications-Settings.extension"
    case timeMachine = "com.apple.Time-Machine-Settings.extension"
    case users = "com.apple.Users-Groups-Settings.extension"
    case dateTime = "com.apple.Date-Time-Settings.extension"
    case privacy = "com.apple.preference.security?Privacy_Bluetooth"

    @MainActor func open() {
        // Deep links vary across releases; fall back to opening the Settings application.
        if let url = URL(string: "x-apple.systempreferences:\(rawValue)"), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

/// Opens Apple's system launchers without simulated shortcuts or Accessibility access.
enum QuickAction: CaseIterable {
    case applications, allWindows

    var title: String { self == .applications ? L("应用启动器") : L("所有窗口") }
    var symbol: String { self == .applications ? "square.grid.3x3.fill" : "rectangle.3.group" }
    var help: String {
        self == .applications ? L("打开系统应用启动器（Apps 或 Launchpad）") : L("打开 Mission Control，查看所有窗口")
    }

    var applicationURL: URL? {
        let paths: [String]
        switch self {
        case .applications:
            paths = ["/System/Applications/Apps.app", "/System/Applications/Launchpad.app", "/Applications/Launchpad.app"]
        case .allWindows:
            paths = ["/System/Applications/Mission Control.app", "/Applications/Mission Control.app"]
        }
        return paths.first(where: { FileManager.default.fileExists(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
}
