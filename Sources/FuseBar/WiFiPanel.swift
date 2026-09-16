import SwiftUI
import CoreWLAN
import CoreLocation

struct NearbyNetwork: Identifiable, Equatable {
    enum Security: String { case open, personal, system }
    let id: String
    let name: String
    let signal: Int
    let security: Security
    let connected: Bool

    static func ordered(_ networks: [NearbyNetwork]) -> [NearbyNetwork] {
        // Merge access points only when both SSID bytes and security class agree.
        let strongest: [NearbyNetwork] = Dictionary(grouping: networks, by: \.id).values.compactMap { group in
            guard let best = group.max(by: { $0.signal < $1.signal }) else { return nil }
            return NearbyNetwork(id: best.id, name: best.name, signal: best.signal, security: best.security,
                                 connected: group.contains(where: \.connected))
        }
        return strongest.sorted {
            if $0.connected != $1.connected { return $0.connected }
            if $0.signal != $1.signal { return $0.signal > $1.signal }
            return $0.id < $1.id
        }
    }
}

/// Accessed exclusively by the panel's serial worker queue.
private final class WiFiScanCache: @unchecked Sendable {
    var networks: [String: CWNetwork] = [:]
}

@MainActor
final class WiFiPanelStore: ObservableObject {
    @Published private(set) var networks: [NearbyNetwork] = []
    @Published private(set) var busy = false
    @Published private(set) var message = L("点击扫描附近网络。网络名称需要定位授权。")
    private let worker = DispatchQueue(label: "com.fusebar.wifi-control", qos: .userInitiated)
    // CWNetwork instances never escape this serial queue.
    private let cache = WiFiScanCache()

    nonisolated private static func security(_ network: CWNetwork) -> NearbyNetwork.Security {
        if network.supportsSecurity(.none) { return .open }
        if [.wpaPersonal, .wpaPersonalMixed, .wpa2Personal, .wpa3Personal, .wpa3Transition]
            .contains(where: { network.supportsSecurity($0) }) { return .personal }
        return .system
    }

    func scan() {
        guard !busy else { return }
        let authorization = CLLocationManager().authorizationStatus
        guard authorization == .authorizedAlways else {
            networks = []
            message = L("请先允许定位读取网络名称，再点击扫描。不会读取设备位置。")
            return
        }
        busy = true
        message = L("正在扫描附近网络…")
        networks = []
        worker.async { [weak self] in
            guard let self else { return }
            do {
                guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else {
                    throw NSError(domain: "FuseBar.WiFi", code: 1)
                }
                let found = try interface.scanForNetworks(withName: nil, includeHidden: false)
                var rows: [NearbyNetwork] = []
                var objects: [String: CWNetwork] = [:]
                let currentSSID = interface.ssidData()
                let currentBSSID = interface.bssid()
                for network in found {
                    guard let name = network.ssid, !name.isEmpty, let data = network.ssidData else { continue }
                    let security = Self.security(network)
                    let key = data.base64EncodedString() + ":" + security.rawValue
                    let connected = currentBSSID != nil ? network.bssid == currentBSSID :
                        (data == currentSSID && network.supportsSecurity(interface.security()))
                    let row = NearbyNetwork(id: key, name: name, signal: network.rssiValue, security: security, connected: connected)
                    rows.append(row)
                    if let old = objects[key], old.rssiValue >= network.rssiValue { continue }
                    objects[key] = network
                }
                self.cache.networks = objects
                let ordered = NearbyNetwork.ordered(rows)
                Task { @MainActor in
                    self.networks = ordered
                    self.busy = false
                    self.message = ordered.isEmpty ? L("未找到可显示的网络。检查 Wi-Fi、定位服务或使用系统设置。") : L("选择网络后确认连接；可能中断当前网络。")
                }
            } catch {
                self.cache.networks = [:]
                Task { @MainActor in
                    self.busy = false
                    self.message = L("扫描失败。请检查 Wi-Fi 电源和定位权限，或打开系统设置。")
                }
            }
        }
    }

    func connect(_ network: NearbyNetwork, password: String, completed: @escaping @MainActor () -> Void) {
        guard !busy, network.security != .system else { return }
        busy = true
        message = L("正在连接…")
        worker.async { [weak self] in
            guard let self else { return }
            let message: String
            do {
                guard let interface = CWWiFiClient.shared().interface(), interface.powerOn(),
                      let target = self.cache.networks[network.id] else { throw NSError(domain: "FuseBar.WiFi", code: 2) }
                try interface.associate(to: target, password: network.security == .open ? nil : password)
                message = interface.ssidData() == target.ssidData ? L("已关联网络；互联网可用性请在使用时确认。") : L("系统尚未确认关联，请刷新状态。")
            } catch {
                message = L("连接未完成。请检查密码和网络，或使用系统 Wi-Fi 设置。")
            }
            Task { @MainActor in
                self.message = message
                self.networks = [] // Never retain a stale current-network checkmark.
                self.busy = false
                completed()
            }
        }
    }

    func setPower(_ enabled: Bool, completed: @escaping @MainActor () -> Void) {
        guard !busy else { return }
        busy = true
        worker.async { [weak self] in
            let message: String
            do {
                guard let interface = CWWiFiClient.shared().interface() else { throw NSError(domain: "FuseBar.WiFi", code: 3) }
                try interface.setPower(enabled)
                message = interface.powerOn() == enabled ? (enabled ? L("Wi-Fi 已开启，请扫描网络。") : L("Wi-Fi 已关闭。")) : L("系统尚未确认 Wi-Fi 电源状态。")
            } catch { message = L("无法改变 Wi-Fi 电源，请使用系统设置。") }
            Task { @MainActor in
                self?.networks = []
                self?.message = message
                self?.busy = false
                completed()
            }
        }
    }
}

struct WiFiPanel: View {
    @ObservedObject var store: StatusStore
    @StateObject private var controller = WiFiPanelStore()
    @State private var selected: NearbyNetwork?
    @State private var password = ""
    @State private var confirmPowerOff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wi-Fi").font(.headline)
                Spacer()
                if controller.busy { ProgressView().controlSize(.small) }
                Button(L("扫描")) { selected = nil; password = ""; controller.scan() }.disabled(controller.busy)
            }
            Text(store.snapshot.wifi.detail).font(.caption).foregroundStyle(.secondary)
            HStack {
                if store.networkNameAccess == .allowed {
                    Label(L("网络名称已授权"), systemImage: "checkmark.circle").foregroundStyle(.secondary)
                } else if store.networkNameAccess == .unknown {
                    Text(L("正在确认权限…")).foregroundStyle(.secondary)
                } else {
                    Button(store.networkNameAccess == .blocked ? L("检查定位权限") : L("允许网络名称")) { store.requestNetworkName() }
                }
                Spacer()
                Button(store.snapshot.wifi.connection == .off ? L("开启 Wi-Fi") : L("关闭 Wi-Fi")) {
                    if store.snapshot.wifi.connection == .off { controller.setPower(true) { store.refresh() } }
                    else { confirmPowerOff = true }
                }.disabled(controller.busy || store.snapshot.wifi.connection == .unknown || store.snapshot.wifi.connection == .unavailable)
            }.font(.caption)
            if let selected {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("连接到 %@？", selected.name)).font(.subheadline)
                    if selected.security == .personal {
                        SecureField(L("网络密码（不保存）"), text: $password)
                    } else { Text(L("此网络未加密。")).font(.caption).foregroundStyle(.secondary) }
                    Text(L("连接可能中断当前网络。")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(L("取消")) { self.selected = nil; password = "" }
                        Spacer()
                        Button(L("连接")) {
                            controller.connect(selected, password: password) { store.refresh() }
                            password = ""
                            self.selected = nil
                        }.disabled(controller.busy || (selected.security == .personal && password.isEmpty))
                    }
                }.padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(controller.networks) { network in
                        Button {
                            if network.security == .system { SettingsDestination.wifi.open() }
                            else { password = ""; selected = network }
                        } label: {
                            HStack {
                                Image(systemName: "wifi")
                                VStack(alignment: .leading) {
                                    Text(network.name).lineLimit(1)
                                    if network.security == .system { Text(L("企业或其他认证 · 系统设置")).font(.caption2) }
                                }
                                Spacer()
                                if network.connected { Image(systemName: "checkmark") }
                                if network.security != .open { Image(systemName: "lock.fill").font(.caption) }
                            }.padding(.vertical, 7).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(controller.busy || network.connected)
                    }
                }
            }.frame(height: selected == nil ? 210 : 90)
            Text(controller.message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("打开 Wi-Fi 设置…")) { SettingsDestination.wifi.open() }
        }.padding(18)
        .onDisappear { password = ""; selected = nil }
        .confirmationDialog(L("关闭 Wi-Fi 会中断当前无线网络。"), isPresented: $confirmPowerOff) {
            Button(L("关闭 Wi-Fi"), role: .destructive) { controller.setPower(false) { store.refresh() } }
        }
    }
}
