import SwiftUI

/// These are explicit system handoffs, not claims that FuseBar implements the controls.
struct SystemControlsView: View {
    @ObservedObject var store: StatusStore
    private let settings: [(String, String, SettingsDestination)] = [
        (L("显示器 / 镜像 / 亮度"), "display", .displays),
        (L("专注模式"), "moon", .focus),
        (L("AirDrop 与接力"), "square.and.arrow.up", .airDrop),
        (L("桌面与程序坞 / 台前调度"), "rectangle.3.group", .desktop),
        (L("键盘 / 输入法 / 背光"), "keyboard", .keyboard),
        (L("辅助功能"), "accessibility", .accessibility),
        (L("通知"), "bell", .notifications),
        ("Time Machine", "clock.arrow.circlepath", .timeMachine),
        (L("用户与群组"), "person.2", .users),
        (L("日期与时间"), "clock", .dateTime),
        (L("电池与电源模式"), "battery.100percent", .battery),
        (L("菜单栏显示选项"), "menubar.rectangle", .menuBar)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("系统功能")).font(.headline)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 5) {
                    Text(context.date, format: .dateTime.year().month().day().weekday().hour().minute())
                    Text(ProcessInfo.processInfo.isLowPowerModeEnabled ? L("低电量模式已开启") : L("低电量模式未开启"))
                        .foregroundStyle(.secondary)
                }.font(.caption)
            }
            Text(L("以下入口在系统应用中完成操作。")).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(settings, id: \.0) { title, symbol, destination in
                        Button { destination.open() } label: {
                            HStack {
                                Image(systemName: symbol).frame(width: 22)
                                Text(title)
                                Spacer()
                                Text(L("设置")).font(.caption2).foregroundStyle(.secondary)
                                Image(systemName: "arrow.up.forward").font(.caption2)
                            }.padding(.horizontal, 6).padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(MenuButtonStyle())
                    }
                    Divider()
                    ForEach([(L("日历"), "com.apple.iCal"), (L("天气"), "com.apple.weather"), (L("快捷指令"), "com.apple.shortcuts")], id: \.1) { title, bundleID in
                        Button { open(bundleID, title: title) } label: {
                            Text(L("打开%@…", title)).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6).padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(MenuButtonStyle())
                    }
                }
            }.frame(height: 320)
            Text(L("Spotlight：⌘ 空格。通知中心、隐私指示和当前应用菜单仍由系统提供。"))
                .font(.caption2).foregroundStyle(.secondary)
        }.font(.system(size: 12)).padding(18)
    }

    private func open(_ bundleID: String, title: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            store.errorMessage = L("当前系统找不到%@。", title)
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            Task { @MainActor in
                if error != nil { store.errorMessage = L("无法打开%@，请从系统应用启动器打开。", title) }
            }
        }
    }
}
