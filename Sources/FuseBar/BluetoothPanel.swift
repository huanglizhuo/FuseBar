import SwiftUI
import CoreBluetooth
import IOBluetooth

struct PairedBluetoothDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let connected: Bool
    var symbol = StatusSymbols.bluetooth
    var isAudioDevice = false
}

@MainActor
final class BluetoothPanelStore: ObservableObject {
    @Published private(set) var devices: [PairedBluetoothDevice] = []
    @Published private(set) var busy = false
    @Published private(set) var message = ""
    @Published private(set) var pendingDeviceID: String?
    @Published private(set) var pendingConnection = false
    @Published private(set) var failed = false
    private var generation = 0
    private let preview: Bool
    private let client: any BluetoothDeviceControlling
    private let authorized: @Sendable () -> Bool
    private static let worker = DispatchQueue(label: "com.fusebar.bluetooth-control", qos: .userInitiated)

    init(preview: Bool = false, client: any BluetoothDeviceControlling = SystemBluetoothDeviceClient(),
         authorized: @escaping @Sendable () -> Bool = { CBManager.authorization == .allowedAlways }) {
        self.preview = preview
        self.client = client
        self.authorized = authorized
        if preview {
            devices = [PairedBluetoothDevice(id: "headphones", name: "Studio Headphones", connected: true, symbol: "headphones"),
                       PairedBluetoothDevice(id: "keyboard", name: "Magic Keyboard", connected: true, symbol: "keyboard"),
                       PairedBluetoothDevice(id: "mouse", name: "Magic Mouse", connected: false, symbol: "computermouse")]
        }
    }

    func refresh(state: BluetoothState) {
        guard state == .on, authorized() else {
            generation += 1
            busy = false
            pendingDeviceID = nil
            devices = []
            message = L("蓝牙开启并授权后可读取已配对设备。")
            failed = false
            return
        }
        guard !busy, !preview else { return }
        busy = true
        let revision = generation
        Self.worker.async { [weak self, client] in
            let rows = client.read()
            Task { @MainActor in
                guard let self, self.generation == revision else { return }
                self.devices = rows ?? []
                self.busy = false
                // Keep a failed operation visible through ordinary status refreshes.
                if !self.failed {
                    self.message = rows == nil ? L("无法读取设备列表，请打开蓝牙设置。") : rows?.isEmpty == true ? L("没有可读取的已配对设备。") : ""
                }
            }
        }
    }

    func setConnected(_ device: PairedBluetoothDevice, connected: Bool, state: BluetoothState,
                      completed: @escaping @MainActor () -> Void = {}) {
        guard !preview, !busy, state == .on, authorized(), devices.contains(where: { $0.id == device.id }) else { return }
        busy = true
        failed = false
        message = ""
        pendingDeviceID = device.id
        pendingConnection = connected
        generation += 1
        let revision = generation
        Self.worker.async { [weak self, client] in
            let error = client.setConnected(address: device.id, connected: connected)
            let rows = client.read()
            Task { @MainActor in
                guard let self, self.generation == revision else { return }
                self.devices = rows ?? []
                self.busy = false
                self.pendingDeviceID = nil
                // No optimistic checkmark: the device must also appear in the fresh list.
                let confirmed = rows?.first(where: { $0.id == device.id })?.connected == connected
                self.failed = error != nil || !confirmed
                self.message = error ?? (confirmed ? "" : L("系统尚未确认设备状态，请刷新后重试。"))
                completed()
            }
        }
    }
    nonisolated static func symbol(major: UInt32, minor: UInt32) -> String {
        // Bluetooth Class of Device values, not guesses based on device names.
        switch major {
        case 1: return "laptopcomputer"
        case 2: return "iphone"
        case 4: return [1, 2, 6].contains(minor) ? "headphones" : "hifispeaker"
        case 5:
            if minor & 0x10 != 0 { return "keyboard" }
            if minor & 0x20 != 0 { return "computermouse" }
            return StatusSymbols.bluetooth
        default: return StatusSymbols.bluetooth
        }
    }

}

struct BluetoothPanel: View {
    @ObservedObject var store: StatusStore
    let preview: Bool
    let isSubmenu: Bool
    @StateObject private var controller: BluetoothPanelStore

    init(store: StatusStore, preview: Bool = false, isSubmenu: Bool = false) {
        self.store = store
        self.preview = preview
        self.isSubmenu = isSubmenu
        _controller = StateObject(wrappedValue: BluetoothPanelStore(preview: preview))
    }

    private var state: BluetoothState { preview ? .on : store.snapshot.bluetooth.state }

    var body: some View {
        VStack(spacing: 0) {
            SystemMenuHeader(title: L("蓝牙"), closesSubmenu: isSubmenu) {
                Text(state == .on ? L("已开启") : state == .off ? L("已关闭") : L("状态未知"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if state == .permissionRequired || state == .denied {
                MenuNotice(text: store.snapshot.bluetooth.detail)
                Button(state == .denied ? L("打开蓝牙隐私设置") : L("允许读取蓝牙状态")) {
                    if state == .denied { SettingsDestination.privacy.open() }
                    else { store.enableBluetooth() }
                }.padding(.bottom, 12)
            } else if state == .on {
                HStack {
                    Text(L("我的设备")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if controller.busy { ProgressView().controlSize(.small) }
                    MenuRefreshButton(title: L("刷新"), disabled: controller.busy) { controller.refresh(state: state) }
                }.padding(.horizontal, 16)
                if !controller.devices.isEmpty {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(controller.devices) { device in
                                MenuListRow(action: { controller.setConnected(device, connected: !device.connected, state: state) { store.refresh(); store.refreshAudioOutputs() } },
                                    disabled: controller.busy,
                                    leading: { DeviceMenuIcon(symbol: device.symbol, selected: device.connected) },
                                    title: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(device.name).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                                            Text(controller.pendingDeviceID == device.id ? (controller.pendingConnection ? L("正在连接…") : L("正在断开…")) : (device.connected ? L("已连接") : L("未连接")))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    },
                                    trailing: {
                                        if controller.pendingDeviceID == device.id { ProgressView().controlSize(.small) }
                                        else { Text(device.connected ? L("断开") : L("连接")).font(.caption).foregroundStyle(.secondary) }
                                    })
                                    .help(device.name + " · " + (device.connected ? L("断开") : L("连接")))
                                    .accessibilityValue(device.connected ? L("已连接") : L("未连接"))
                                    .accessibilityHint(device.connected ? L("断开") : L("连接"))
                            }
                        }.padding(.horizontal, 8)
                    }.frame(height: menuListHeight(count: controller.devices.count, rowHeight: 50, cap: 250))
                }
                if !controller.message.isEmpty { MenuNotice(text: controller.message, error: controller.failed) }
            } else {
                MenuNotice(text: store.snapshot.bluetooth.detail)
            }
            SystemMenuFooter(title: L("管理蓝牙连接…"), destination: .bluetooth)
        }
        .onAppear { if !preview { controller.refresh(state: state) } }
        .onChange(of: store.snapshot.bluetooth) { _, _ in if !preview { controller.refresh(state: state) } }
    }
}
