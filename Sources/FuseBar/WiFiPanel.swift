import SwiftUI
import CoreWLAN

struct NearbyNetwork: Identifiable, Equatable {
    enum Security: String { case open, personal, system }
    let id: String
    let name: String
    let signal: Int
    let security: Security
    let connected: Bool
    var signalFraction: Double { Double(WiFiStatus(rssi: signal).bars) / 3 }

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

enum WiFiScanFailure: Error {
    case interfaceUnavailable, powerOff

    static func message(for error: Error) -> String {
        switch error as? WiFiScanFailure {
        case .interfaceUnavailable: return L("无法访问系统 Wi-Fi 服务，请重新启动 FuseBar 后重试。")
        case .powerOff: return L("Wi-Fi 已关闭，请开启后重新扫描。")
        case nil:
            let error = error as NSError
            return L("扫描未完成（%@ %ld），请重试。", error.domain, error.code)
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
    @Published private(set) var message = ""
    @Published private(set) var connectingID: String?
    @Published private(set) var failed = false
    private var generation = 0

    init(preview: Bool = false) {
        if preview {
            networks = [NearbyNetwork(id: "home", name: "Home Wi-Fi", signal: -48, security: .personal, connected: true),
                        NearbyNetwork(id: "studio", name: "Studio", signal: -64, security: .personal, connected: false),
                        NearbyNetwork(id: "guest", name: "Guest", signal: -78, security: .open, connected: false)]
        }
    }

    func invalidate() {
        generation += 1
        networks = []
        busy = false
        connectingID = nil
        failed = false
        message = ""
        worker.async { [cache] in cache.networks = [:] }
    }

    private let worker = DispatchQueue(label: "com.fusebar.wifi-control", qos: .userInitiated)
    // CWNetwork instances never escape this serial queue.
    private let cache = WiFiScanCache()

    nonisolated private static func security(_ network: CWNetwork) -> NearbyNetwork.Security {
        if network.supportsSecurity(.none) { return .open }
        if [.wpaPersonal, .wpaPersonalMixed, .wpa2Personal, .wpa3Personal, .wpa3Transition]
            .contains(where: { network.supportsSecurity($0) }) { return .personal }
        return .system
    }

    func scan(access: NetworkNameAccess) {
        guard !busy else { return }
        // Use the long-lived manager in StatusStore. A newly created manager can
        // temporarily report notDetermined even after permission was granted.
        guard access == .allowed else {
            networks = []
            message = L("请先允许定位读取网络名称，再点击扫描。不会读取设备位置。")
            return
        }
        busy = true
        generation += 1
        failed = false
        let revision = generation
        message = L("正在扫描附近网络…")
        worker.async { [weak self] in
            guard let self else { return }
            do {
                guard let interface = CWWiFiClient.shared().interface() else { throw WiFiScanFailure.interfaceUnavailable }
                guard interface.powerOn() else { throw WiFiScanFailure.powerOff }
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
                    guard self.generation == revision else { return }
                    self.networks = ordered
                    self.busy = false
                    self.message = ordered.isEmpty ? L("未找到可显示的网络。检查 Wi-Fi、定位服务或使用系统设置。") : ""
                }
            } catch {
                self.cache.networks = [:]
                Task { @MainActor in
                    guard self.generation == revision else { return }
                    self.networks = []
                    self.busy = false
                    self.failed = true
                    self.message = WiFiScanFailure.message(for: error)
                }
            }
        }
    }

    func connect(_ network: NearbyNetwork, password: String, access: NetworkNameAccess, completed: @escaping @MainActor (Bool) -> Void) {
        guard !busy, access == .allowed, !network.connected, network.security != .system else { return }
        busy = true
        generation += 1
        failed = false
        connectingID = network.id
        let revision = generation
        message = L("正在连接…")
        worker.async { [weak self] in
            guard let self else { return }
            let message: String
            var connected = false
            do {
                guard let interface = CWWiFiClient.shared().interface(), interface.powerOn(),
                      let target = self.cache.networks[network.id] else { throw NSError(domain: "FuseBar.WiFi", code: 2) }
                try interface.associate(to: target, password: network.security == .open ? nil : password)
                connected = interface.ssidData() == target.ssidData && target.supportsSecurity(interface.security())
                message = connected ? L("已关联网络；互联网可用性请在使用时确认。") : L("系统尚未确认关联，请刷新状态。")
            } catch {
                message = L("连接未完成。请检查密码和网络，或使用系统 Wi-Fi 设置。")
            }
            Task { @MainActor in
                guard self.generation == revision else { return }
                self.message = connected ? "" : message
                self.failed = !connected
                self.networks = self.networks.map {
                    NearbyNetwork(id: $0.id, name: $0.name, signal: $0.signal, security: $0.security,
                                  connected: connected && $0.id == network.id)
                }
                self.connectingID = nil
                self.busy = false
                self.reconcileConnection()
                completed(connected)
            }
        }
    }

    /// Refresh association markers without scanning or discarding the user's list.
    func reconcileConnection() {
        guard !busy, !networks.isEmpty else { return }
        let revision = generation
        worker.async { [weak self] in
            guard let self else { return }
            let interface = CWWiFiClient.shared().interface()
            let ssid = interface?.ssidData()
            let security = interface?.security()
            let connectedIDs = Set(self.cache.networks.compactMap { id, network -> String? in
                guard interface?.powerOn() == true, let ssid, let security,
                      network.ssidData == ssid, network.supportsSecurity(security) else { return nil }
                return id
            })
            Task { @MainActor in
                guard self.generation == revision, !self.busy else { return }
                self.networks = self.networks.map {
                    NearbyNetwork(id: $0.id, name: $0.name, signal: $0.signal, security: $0.security,
                                  connected: connectedIDs.contains($0.id))
                }
            }
        }
    }

    func setPower(_ enabled: Bool, completed: @escaping @MainActor () -> Void) {
        guard !busy else { return }
        busy = true
        generation += 1
        failed = false
        let revision = generation
        worker.async { [weak self] in
            let message: String
            var confirmed = false
            do {
                guard let interface = CWWiFiClient.shared().interface() else { throw NSError(domain: "FuseBar.WiFi", code: 3) }
                try interface.setPower(enabled)
                confirmed = interface.powerOn() == enabled
                message = confirmed ? "" : L("系统尚未确认 Wi-Fi 电源状态。")
            } catch { message = L("无法改变 Wi-Fi 电源，请使用系统设置。") }
            Task { @MainActor in
                guard let self, self.generation == revision else { return }
                self.networks = []
                self.message = message
                self.failed = !confirmed
                self.busy = false
                completed()
            }
        }
    }
}

struct WiFiPanel: View {
    @ObservedObject var store: StatusStore
    let preview: Bool
    let isSubmenu: Bool
    @StateObject private var controller: WiFiPanelStore
    @State private var selected: NearbyNetwork?
    @State private var password = ""
    @State private var confirmPowerOff = false
    @State private var expanded = true
    @FocusState private var passwordFocused: Bool

    init(store: StatusStore, preview: Bool = false, isSubmenu: Bool = false) {
        self.store = store
        self.preview = preview
        self.isSubmenu = isSubmenu
        _controller = StateObject(wrappedValue: WiFiPanelStore(preview: preview))
    }

    private var wifi: WiFiStatus { store.snapshot.wifi }
    private var powered: Bool { wifi.connection == .connected || wifi.connection == .disconnected }
    private var allowed: Bool { preview || store.networkNameAccess == .allowed }
    private var others: [NearbyNetwork] { controller.networks.filter { !$0.connected } }

    var body: some View {
        VStack(spacing: 0) {
            SystemMenuHeader(title: "Wi-Fi", closesSubmenu: isSubmenu) {
                if controller.busy && !powered { ProgressView().controlSize(.small) }
                Toggle("Wi-Fi", isOn: Binding(get: { powered }, set: { enabled in
                    if enabled { controller.setPower(true) { store.refresh() } }
                    else { confirmPowerOff = true }
                })).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .disabled(controller.busy || (wifi.connection != .off && !powered))
            }
            if wifi.connection == .connected {
                HStack(spacing: 10) {
                    DeviceMenuIcon(symbol: StatusSymbols.wifi(wifi), selected: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(wifi.name ?? L("已连接 · 网络名称暂不可用")).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(wifi.hotspotStyle ? L("热点 / 按流量计费网络 · 已连接") : L("已连接"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                }.padding(10).background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8).padding(.bottom, 8).help(wifi.detail)
            } else {
                MenuNotice(text: wifi.detail)
            }
            if powered {
                if !allowed {
                    MenuNotice(text: L("需要定位权限以显示附近网络；不会读取设备位置。"))
                    Button(store.networkNameAccess == .blocked ? L("检查定位权限") : L("允许网络名称")) {
                        store.requestNetworkName()
                    }.disabled(store.networkNameAccess == .unknown)
                        .padding(.horizontal, 16).padding(.bottom, 12)
                } else {
                    networkList
                }
            }
            if let selected { joinForm(selected) }
            if !controller.message.isEmpty && ((powered && allowed) || controller.failed) {
                MenuNotice(text: controller.message, error: controller.failed)
            }
            SystemMenuFooter(title: L("打开 Wi-Fi 设置…"), destination: .wifi)
        }
        .onAppear { scanIfReady() }
        .onChange(of: store.networkNameAccess) { _, _ in
            if allowed { scanIfReady() } else { clearSelection(); controller.invalidate() }
        }
        .onChange(of: store.snapshot.wifi) { _, _ in
            if !preview { controller.reconcileConnection() }
        }
        .onChange(of: powered) { _, value in
            if value { scanIfReady() } else { clearSelection(); controller.invalidate() }
        }
        .onDisappear { clearSelection(); if !preview { controller.invalidate() } }
        .confirmationDialog(L("关闭 Wi-Fi 会中断当前无线网络。"), isPresented: $confirmPowerOff) {
            Button(L("关闭 Wi-Fi"), role: .destructive) { controller.setPower(false) { store.refresh() } }
        }
    }

    private var networkList: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 16)
            HStack(spacing: 6) {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .semibold))
                        Text(L("其他网络")).font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(.secondary).padding(.vertical, 8)
                }.buttonStyle(.plain)
                Spacer()
                if controller.busy { ProgressView().controlSize(.small) }
                Button { controller.scan(access: store.networkNameAccess) } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 24, height: 24)
                }.buttonStyle(MenuButtonStyle()).help(L("扫描")).accessibilityLabel(L("扫描"))
                    .disabled(controller.busy || selected != nil)
            }.padding(.horizontal, 16)
            if expanded && !others.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(others) { network in
                            Button {
                                if network.security == .system { SettingsDestination.wifi.open() }
                                else { password = ""; selected = network; passwordFocused = true }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "wifi", variableValue: network.signalFraction)
                                        .font(.system(size: 15)).frame(width: 30)
                                    Text(network.name).font(.system(size: 13)).lineLimit(1)
                                    Spacer(minLength: 4)
                                    if controller.connectingID == network.id { ProgressView().controlSize(.small) }
                                    else if network.security == .system { Image(systemName: "arrow.up.forward").font(.caption) }
                                    if network.security != .open { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.secondary) }
                                }.padding(.horizontal, 8).padding(.vertical, 9).contentShape(Rectangle())
                            }.buttonStyle(MenuButtonStyle(selected: selected?.id == network.id))
                                .disabled(controller.busy).help(network.name)
                                .accessibilityValue(network.security == .open ? L("此网络未加密。") : network.security == .system ? L("企业或其他认证 · 系统设置") : L("需要密码"))
                        }
                    }.padding(.horizontal, 8)
                }.frame(height: min(CGFloat(others.count) * 38, selected == nil ? 228 : 114))
            }
        }
    }

    private func joinForm(_ network: NearbyNetwork) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("连接到 %@？", network.name)).font(.system(size: 12, weight: .semibold)).lineLimit(2)
            if network.security == .personal {
                SecureField(L("网络密码（不保存）"), text: $password).textFieldStyle(.roundedBorder)
                    .focused($passwordFocused).onSubmit { join(network) }
            } else { Text(L("此网络未加密。")).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button(L("取消")) { clearSelection() }.disabled(controller.busy)
                Spacer()
                Button(L("连接")) { join(network) }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.busy || (network.security == .personal && password.isEmpty))
            }
        }.padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .padding(8)
    }

    private func join(_ network: NearbyNetwork) {
        guard !controller.busy, network.security != .personal || !password.isEmpty else { return }
        controller.connect(network, password: password, access: store.networkNameAccess) { connected in
            store.refresh()
            if connected { clearSelection() } else { passwordFocused = true }
        }
        password = ""
    }

    private func clearSelection() { selected = nil; password = ""; passwordFocused = false }
    private func scanIfReady() {
        guard !preview, powered, allowed else { return }
        controller.scan(access: store.networkNameAccess)
    }
}
