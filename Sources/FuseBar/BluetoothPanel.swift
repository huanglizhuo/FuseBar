import SwiftUI
import CoreBluetooth
import IOBluetooth

struct PairedBluetoothDevice: Identifiable {
    let id: String
    let name: String
    let connected: Bool
}

@MainActor
final class BluetoothPanelStore: ObservableObject {
    @Published private(set) var devices: [PairedBluetoothDevice] = []
    @Published private(set) var busy = false
    @Published private(set) var message = ""
    private let worker = DispatchQueue(label: "com.fusebar.bluetooth-list", qos: .utility)

    func refresh(state: BluetoothState) {
        guard !busy else { return }
        guard state == .on, CBManager.authorization == .allowedAlways else {
            devices = []
            message = L("蓝牙开启并授权后可读取已配对设备。")
            return
        }
        busy = true
        worker.async { [weak self] in
            let paired = CBManager.authorization == .allowedAlways ? IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] : nil
            let devices = (paired ?? []).compactMap { device -> PairedBluetoothDevice? in
                guard let address = device.addressString else { return nil }
                return PairedBluetoothDevice(id: address, name: device.name ?? L("蓝牙设备"), connected: device.isConnected())
            }.sorted {
                if $0.connected != $1.connected { return $0.connected }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            Task { @MainActor in
                self?.devices = devices
                self?.busy = false
                self?.message = paired == nil ? L("无法读取设备列表，请打开蓝牙设置。") : devices.isEmpty ? L("没有可读取的已配对设备。") : ""
            }
        }
    }
}

struct BluetoothPanel: View {
    @ObservedObject var store: StatusStore
    @StateObject private var controller = BluetoothPanelStore()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("蓝牙设备")).font(.headline)
                Spacer()
                if controller.busy { ProgressView().controlSize(.small) }
                Button(L("刷新")) { controller.refresh(state: store.snapshot.bluetooth.state) }.disabled(controller.busy)
            }
            if store.snapshot.bluetooth.state == .permissionRequired {
                Button(L("允许读取蓝牙状态")) { store.enableBluetooth() }
            } else if store.snapshot.bluetooth.state == .denied {
                Button(L("打开蓝牙隐私设置")) { SettingsDestination.privacy.open() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(controller.devices) { device in
                        HStack {
                            Image(systemName: StatusSymbols.bluetooth)
                            Text(device.name).lineLimit(2)
                            Spacer()
                            Text(device.connected ? L("已连接") : L("未连接")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !controller.message.isEmpty { Text(controller.message).font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 260)
            Text(L("连接、断开、配对和蓝牙电源暂由系统设置管理。这里不扫描附近设备。"))
                .font(.caption).foregroundStyle(.secondary)
            Button(L("管理蓝牙连接…")) { SettingsDestination.bluetooth.open() }
        }.padding(18)
        .onAppear { controller.refresh(state: store.snapshot.bluetooth.state) }
        .onChange(of: store.snapshot.bluetooth) { _, _ in controller.refresh(state: store.snapshot.bluetooth.state) }
    }
}
