import AppKit
import ServiceManagement
import SwiftUI

enum SettingsTab: Hashable { case general, projects }

/// Settings live in a regular window: more room than the menu panel, which stays short.
struct SettingsView: View {
    @ObservedObject var store: StatusStore
    @ObservedObject private var inputSources = InputSourceStore.shared
    @ObservedObject private var shortcut = GlobalShortcut.shared
    @StateObject private var projects: CodingProjects
    @AppStorage("codingLayout") private var codingLayout = false
    @State private var tab: SettingsTab
    private let preview: Bool

    init(store: StatusStore, tab: SettingsTab = .general, preview: Bool = false) {
        self.store = store
        self.preview = preview
        _projects = StateObject(wrappedValue: CodingProjects(defaults: store.defaults))
        _codingLayout = AppStorage(wrappedValue: false, "codingLayout", store: store.defaults)
        _tab = State(initialValue: tab)
    }

    var body: some View {
        TabView(selection: $tab) {
            ScrollView { general }.tabItem { Text(L("通用")) }.tag(SettingsTab.general)
            ScrollView { ProjectEditorView(projects: projects) }.tabItem { Text(L("项目工作台")) }.tag(SettingsTab.projects)
        }
        .padding(12)
        .frame(width: 460, height: 600)
        .environment(\.locale, L10n.locale)
        .onAppear { if !preview { store.refreshLoginStatus() } }
    }

    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L("开发版") }

    private var general: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("编码工作台")).font(.headline)
            Toggle(L("编码布局：优先显示应用和项目"), isOn: $codingLayout)
            Button(L("项目工作台")) { tab = .projects }
            ShortcutSettingsView()
            Button(L("Dock 自动隐藏设置 ↗")) { SettingsDestination.desktop.open() }
            Text(L("在系统设置中开启自动隐藏 Dock，为代码和预览腾出空间；也可在那里恢复。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Picker(L("默认中心图标"), selection: $store.preferences.center) {
                Text(L("网络连接")).tag(CenterIndicator.network)
                Text(L("声音输出")).tag(CenterIndicator.sound)
            }
            Toggle(L("中心常驻输入法图标"), isOn: $inputSources.alwaysShow)
            Text(L("切换输入源后显示图标 2 秒，再恢复所选中心图标；开启常驻输入法时优先显示输入法。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(L("在圆环中显示")).font(.system(size: 13, weight: .semibold))
            Toggle(L("电池 · 外环"), isOn: $store.preferences.battery)
            Toggle(L("网络状态与提醒"), isOn: $store.preferences.wifi)
            Toggle(L("声音状态与音量"), isOn: $store.preferences.sound)
            Picker(L("底部显示"), selection: $store.preferences.bottomIndicator) {
                Text(L("状态提醒与音量四点")).tag(BottomIndicator.status)
                Text(L("电量百分比数字")).tag(BottomIndicator.batteryLevel)
                Text(L("音量百分比数字")).tag(BottomIndicator.volumeLevel)
            }
            Text(L("平时四点表示约 25%、50%、75%、100% 的音量；有提醒时替换为最重要的一项：严重低电、断网、低电、充电或静音。全部状态可在详情中查看。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(L("选择数字后，圆环底部常显所选百分比，对应数据不可用时回落到提醒与四点。面板中的圆环按系统电池颜色着色：充电为绿色，严重低电为红色；菜单栏图标保持单色。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Toggle(L("悬停摘要包含蓝牙状态"), isOn: $store.preferences.bluetooth)
            Toggle(L("登录时启动"), isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) }))
            if store.loginNeedsApproval {
                Button(L("在系统设置中批准登录启动")) { SMAppService.openSystemSettingsLoginItems() }.font(.caption)
            }
            Button(L("打开菜单栏设置")) { SettingsDestination.menuBar.open() }
            Divider()
            diagnostics
            Link(L("隐私政策"), destination: URL(string: "https://github.com/huanglizhuo/FuseBar/blob/main/docs/PRIVACY.md")!)
            Link(L("帮助与反馈"), destination: URL(string: "https://github.com/huanglizhuo/FuseBar/issues")!)
            Text(L("FuseBar %@ · 免费\n声音变化即时监听；其他状态约每 3 秒更新。", version))
                .font(.caption2).foregroundStyle(.secondary)
            if !Distribution.isAppStore {
                // Store builds update through the App Store. Others get a link, never a background check.
                Link(L("查看最新版本 ↗"), destination: URL(string: "https://github.com/huanglizhuo/FuseBar/releases/latest")!)
                    .font(.caption)
            }
        }.toggleStyle(.checkbox).font(.system(size: 12)).padding(18)
    }

    private var diagnostics: some View {
        DisclosureGroup(L("诊断信息")) {
            let report = store.diagnostics(inputSources: inputSources.sources.count, shortcutSet: shortcut.combination != nil,
                                           codingLayout: codingLayout)
            VStack(alignment: .leading, spacing: 8) {
                Text(report).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(L("复制诊断信息")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                }
                Text(L("不含 Wi-Fi、设备、文件或项目名称；最近的错误提示按原文附上。粘贴前请先检查。"))
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 6)
        }
    }
}

enum Distribution {
    /// Mac App Store installs carry a receipt; Developer ID and local builds do not.
    static var isAppStore: Bool {
        FileManager.default.fileExists(atPath: Bundle.main.bundleURL.appendingPathComponent("Contents/_MASReceipt/receipt").path)
    }
    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}

extension StatusStore {
    /// De-identified support summary: states and counts only, never network, device, file or project names.
    func diagnostics(inputSources: Int, shortcutSet: Bool, codingLayout: Bool) -> String {
        let info = Bundle.main.infoDictionary
        let battery = snapshot.battery, wifi = snapshot.wifi, sound = snapshot.sound
        return [
            "FuseBar \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?")) · \(Distribution.isAppStore ? "App Store" : "Developer ID or local build")",
            "\(ProcessInfo.processInfo.operatingSystemVersionString) · \(Distribution.architecture) · \(L10n.language)",
            "Battery: \(battery.availability), \(battery.level)%, charging \(battery.charging), external power \(battery.externalPower)",
            "Wi-Fi: \(wifi.connection), name \(wifi.name == nil ? "unavailable" : "withheld"), bars \(wifi.bars), hotspot \(wifi.hotspotStyle), path unavailable \(wifi.pathUnavailable), name access \(networkNameAccess)",
            "Bluetooth: \(snapshot.bluetooth.state), connected devices \(snapshot.bluetooth.devices.count)",
            "Sound: available \(sound.available), volume control \(sound.canSetVolume), mute control \(sound.canSetMute), outputs \(audioOutputs.count)",
            "Input sources \(inputSources) · quick-open shortcut \(shortcutSet ? "set" : "not set") · \(codingLayout ? "coding" : "status") layout",
            "Login item: \(loginEnabled ? "enabled" : loginNeedsApproval ? "needs approval" : "off")",
            "Last error: \(errorMessage ?? "none")"
        ].joined(separator: "\n")
    }
}

/// Escape and ⌘W close the window; an accessory app has no File menu to provide ⌘W.
final class SettingsWindow: NSWindow {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = L("FuseBar 设置")
        isReleasedWhenClosed = false
    }
    override func cancelOperation(_ sender: Any?) { performClose(nil) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
