import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var store: StatusStore
    @State private var page: Page = .status
    @State private var editingVolume = false
    @State private var volume = 0.0
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    private let preview: Bool
    enum Page { case status, settings, guide }

    init(store: StatusStore, initialPage: Page = .status, preview: Bool = false) {
        self.store = store
        self.preview = preview
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                OrbView(snapshot: store.snapshot, preferences: store.preferences).frame(width: 38, height: 38)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MergeBar").font(.system(size: 17, weight: .semibold))
                    Text(store.snapshot.headline(store.preferences)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(18)
            Divider()
            if page == .settings { settings }
            else if page == .guide || (!preview && !onboardingComplete) { guide }
            else { status }
            if let error = store.errorMessage {
                HStack(alignment: .top) {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("关闭错误提示")
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            Divider()
            HStack {
                Button(page == .status ? "设置…" : "返回状态") {
                    if page == .status { page = .settings; store.refreshLoginStatus() }
                    else { page = .status }
                }
                .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button { page = .guide } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("图标说明与使用引导")
                Button("退出") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }.buttonStyle(.borderless).font(.caption).padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear {
            volume = Double(store.snapshot.sound.volume ?? 0)
            store.refresh()
        }
        .onChange(of: store.snapshot.sound.volume) { _, value in
            if !editingVolume { volume = Double(value ?? 0) }
        }
    }

    private var status: some View {
        VStack(spacing: 0) {
            statusRow("电池", detail: store.snapshot.battery.detail, symbol: "battery.75percent", destination: .battery)
            Divider().padding(.leading, 48)
            statusRow("Wi-Fi", detail: store.snapshot.wifi.detail, symbol: "wifi", destination: .wifi)
            if store.snapshot.wifi.connection == .connected && store.snapshot.wifi.name == nil {
                VStack(alignment: .leading, spacing: 5) {
                    Button("显示网络名称…") { store.requestNetworkName() }.font(.caption)
                    Text("需 macOS 定位授权；不会采集位置。")
                        .font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 48).padding(.bottom, 12)
            }
            Divider().padding(.leading, 48)
            VStack(alignment: .leading, spacing: 0) {
                statusRow("蓝牙", detail: store.snapshot.bluetooth.detail, symbol: "wave.3.right", destination: .bluetooth)
                if store.snapshot.bluetooth.state == .permissionRequired {
                    Button("允许读取蓝牙状态") { store.enableBluetooth() }
                        .font(.caption).padding(.leading, 48).padding(.bottom, 12)
                } else if store.snapshot.bluetooth.state == .denied {
                    Button("打开蓝牙隐私设置") { SettingsDestination.privacy.open() }
                        .font(.caption).padding(.leading, 48).padding(.bottom, 12)
                }
            }
            Divider().padding(.leading, 48)
            statusRow("声音", detail: store.snapshot.sound.detail,
                      symbol: store.snapshot.sound.effectivelyMuted ? "speaker.slash" : "speaker.wave.2", destination: .sound)
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $volume, in: 0...1, onEditingChanged: { editing in
                    editingVolume = editing
                    if !editing { store.setVolume(volume) }
                })
                .onChange(of: volume) { _, value in
                    // Keyboard/VoiceOver increments do not necessarily enter a drag session.
                    if !editingVolume, abs(value - Double(store.snapshot.sound.volume ?? 0)) > 0.005 {
                        store.setVolume(value)
                    }
                }
                .disabled(!store.snapshot.sound.canSetVolume)
                .accessibilityLabel("输出音量")
                .accessibilityValue("\(Int(volume * 100))%")
                Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 12)
            if store.snapshot.sound.muted == true {
                Text("系统静音已开启；调整音量不会自动取消静音。")
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 10)
            }
            HStack {
                Text("仅在本机读取").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button("刷新") { store.refresh() }.buttonStyle(.borderless).font(.caption2)
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
    }

    private func statusRow(_ title: String, detail: String, symbol: String, destination: SettingsDestination) -> some View {
        Button { destination.open() } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16)).frame(width: 20).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 18).padding(.vertical, 13).contentShape(Rectangle())
        }.buttonStyle(.plain).help("打开\(title)系统设置")
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("在圆环中显示").font(.system(size: 13, weight: .semibold))
            Toggle("电池 · 外环", isOn: $store.preferences.battery)
            Toggle("Wi-Fi · 中心", isOn: $store.preferences.wifi)
            Toggle("蓝牙 · 底部连接点", isOn: $store.preferences.bluetooth)
            Toggle("静音 · 右下角标", isOn: $store.preferences.sound)
            Text("这些开关只调整 MergeBar 图标。详情始终可查看。")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack { Text("外观"); Spacer(); Text("Compact Orb").foregroundStyle(.secondary) }
            Toggle("登录时启动", isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) }))
            if store.loginNeedsApproval {
                Button("在系统设置中批准登录启动") { SMAppService.openSystemSettingsLoginItems() }.font(.caption)
            }
            Divider()
            Button("如何隐藏原生菜单栏图标") { page = .guide }
            Text("MergeBar 0.1 · 开发预览\n状态约每 3 秒更新；网络名称可能受系统保护。")
                .font(.caption2).foregroundStyle(.secondary)
        }.toggleStyle(.checkbox).font(.system(size: 12)).padding(18)
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("四个图标，一个入口。").font(.system(size: 21, weight: .semibold))
            HStack(spacing: 13) {
                ForEach(["wifi", "wave.3.right", "speaker.wave.2", "battery.75percent"], id: \.self) { Image(systemName: $0) }
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                OrbView(snapshot: .normal).frame(width: 32, height: 32)
            }.frame(maxWidth: .infinity).padding(.vertical, 8).accessibilityHidden(true)
            Text("外环读电量，中心看 Wi-Fi。底部实点表示蓝牙设备已连接；右下叉号表示静音。")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("保留重要状态，收起重复图标。")
                .font(.system(size: 13, weight: .medium))
            Text("前往系统设置的“菜单栏”或“控制中心”，手动隐藏 Wi-Fi、蓝牙、声音和电池图标。先试用，再决定隐藏哪些。")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("打开菜单栏设置") { SettingsDestination.menuBar.open() }
            Button("开始使用") { onboardingComplete = true; page = .status }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(18)
    }
}

struct OrbGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("MergeBar / 状态图谱").font(.system(size: 24, weight: .semibold))
            Text("相同几何，真实尺寸与放大视图。图谱使用模拟状态，不读取或改变系统设置。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(140)), count: 5), spacing: 24) {
                ForEach(StatusSnapshot.scenarios, id: \.0) { title, snapshot in
                    VStack(spacing: 12) {
                        OrbView(snapshot: snapshot).frame(width: 66, height: 66)
                        OrbView(snapshot: snapshot).frame(width: 22, height: 22)
                        Text(title).font(.system(size: 12))
                    }.frame(width: 140, height: 145)
                }
            }
        }.padding(32).background(Color(nsColor: .windowBackgroundColor))
    }
}

struct InterfaceGallery: View {
    @ObservedObject var store: StatusStore
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("MergeBar / 按需展开").font(.system(size: 26, weight: .semibold))
            Text("首次使用 → 状态详情 → 偏好设置 · 以下均为模拟状态预览")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 24) {
                ForEach([PopoverView.Page.guide, .status, .settings], id: \.self) { page in
                    PopoverView(store: store, initialPage: page, preview: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                }
            }
        }.padding(32).background(Color(nsColor: .windowBackgroundColor))
    }
}
