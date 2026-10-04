import SwiftUI
import XCTest
@testable import FuseBar

final class MenuSearchTests: XCTestCase {
    private let entries = [
        MenuSearchEntry(id: "app:editor", title: "Éditeur", category: "Application", symbol: "app", destination: .application(URL(fileURLWithPath: "/Applications/Editor.app"))),
        MenuSearchEntry(id: "file:work", title: "工作目录", category: "Files", symbol: "folder", destination: .file(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)),
        MenuSearchEntry(id: "action:sound", title: "声音输出", category: "Action", symbol: "speaker", destination: .action("sound"), aliases: ["sound"])
    ]
    func testSearchAcrossKindsWithoutLosingDestination() {
        XCTAssertEqual(MenuSearchModel.results(entries, query: " editeur ").first?.destination, entries[0].destination)
        XCTAssertEqual(MenuSearchModel.results(entries, query: "工作").first?.destination, entries[1].destination)
        XCTAssertEqual(MenuSearchModel.results(entries, query: "sound").first?.destination, .action("sound"))
        XCTAssertTrue(MenuSearchModel.results(entries, query: "unmatched").isEmpty)
    }
    func testEmptyQueryHasNoResultsAndDuplicatesCollapse() {
        XCTAssertTrue(MenuSearchModel.results(entries, query: "").isEmpty)
        XCTAssertTrue(MenuSearchModel.results(entries, query: " \n").isEmpty)
        XCTAssertEqual(MenuSearchModel.results(entries + entries, query: "Action").count, 1)
    }

    private func app(_ bundleID: String, _ name: String, file: String? = nil) -> MenuSearchEntry {
        MenuSearchEntry(id: "app:" + bundleID, title: name, category: "Apps", symbol: "app",
                        destination: .application(URL(fileURLWithPath: "/Applications/\(file ?? name).app")),
                        aliases: [file ?? name, bundleID.components(separatedBy: ".").last!])
    }

    func testPrefixAndWordMatchesOutrankSubstringsAndRecentOrderBreaksTies() {
        // Running apps come first (by recent use), then installed apps by name, as in the panel.
        let apps = [app("com.apple.MobileSMS", "Messages"), app("com.apple.Notes", "Notes"),
                    app("com.apple.Safari", "Safari"), app("com.apple.systempreferences", "System Settings"),
                    app("com.apple.Terminal", "Terminal"), app("com.apple.TextEdit", "TextEdit")]
        func titles(_ query: String) -> [String] { MenuSearchModel.results(apps, query: query).map(\.title) }
        XCTAssertEqual(titles("sa"), ["Safari", "Messages"])
        XCTAssertEqual(titles("te").prefix(3), ["Terminal", "TextEdit", "Notes"])
        XCTAssertEqual(titles("set"), ["System Settings"])
        // Categories need three characters, so one letter no longer lists every app.
        XCTAssertFalse(titles("a").contains("Notes"))
        XCTAssertEqual(titles("apps").count, apps.count)
    }

    func testAliasesInitialsAndPinyinFindLocalizedNames() {
        let apps = [app("com.microsoft.VSCode", "Visual Studio Code"), app("com.apple.Terminal", "终端", file: "Terminal"),
                    app("com.tencent.xinWeChat", "微信", file: "WeChat")]
        func first(_ query: String) -> String? { MenuSearchModel.results(apps, query: query).first?.title }
        XCTAssertEqual(first("terminal"), "终端")
        XCTAssertEqual(first("vscode"), "Visual Studio Code")
        XCTAssertEqual(first("vsc"), "Visual Studio Code")
        XCTAssertEqual(first("code"), "Visual Studio Code")
        XCTAssertEqual(first("wx"), "微信")
        XCTAssertEqual(first("weixin"), "微信")
        XCTAssertEqual(first("zhongduan"), "终端")
        XCTAssertEqual(MenuSearchModel.pinyin("系统设置"), ["xitongshezhi", "xtsz"])
        XCTAssertEqual(MenuSearchModel.pinyin("Safari"), [])
    }

    func testSystemSettingsPanesAreSearchableByEnglishKeyword() {
        let panes = SettingsDestination.searchable
        XCTAssertEqual(Set(panes.map(\.destination.rawValue)).count, 12)
        let entries = panes.map {
            MenuSearchEntry(id: "settings:" + $0.destination.rawValue, title: $0.title, category: "System Settings",
                            symbol: $0.symbol, destination: .settings($0.destination), aliases: [$0.keyword])
        }
        XCTAssertEqual(MenuSearchModel.results(entries, query: "focus").first?.destination, .settings(.focus))
        XCTAssertEqual(MenuSearchModel.results(entries, query: "dock").first?.destination, .settings(.desktop))
    }

    @MainActor private func hostedPanel(_ view: PopoverView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 640), styleMask: .titled, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return window
    }

    @MainActor private func pressReturn(in window: NSWindow) throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                    windowNumber: window.windowNumber, context: nil, characters: "\r",
                                                    charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        window.sendEvent(event)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    @MainActor func testReturnRunsBestResultAndDeviceResultsOpenTheirSubmenu() throws {
        let suite = "FuseBarTests.SearchActions.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let apps = [("com.apple.MobileSMS", "Messages"), ("com.apple.Safari", "Safari")].map {
            ShelfApplication(id: $0.0, name: $0.1, url: URL(fileURLWithPath: "/Applications/\($0.1).app"), running: true)
        }
        let shelf = ApplicationShelf(defaults: defaults, readApplications: { apps })
        shelf.refresh()
        let deadline = Date().addingTimeInterval(2)
        while shelf.running.count < 2 && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        let store = StatusStore(defaults: defaults, demo: true)

        var opened: [URL] = []
        let appWindow = hostedPanel(PopoverView(store: store, preview: true, initialQuery: "sa", focusSearch: true,
                                                onOpenApplication: { opened.append($0) }, shelf: shelf))
        defer { appWindow.orderOut(nil) }
        try pressReturn(in: appWindow)
        XCTAssertEqual(opened, [apps[1].url!], "Safari's prefix match outranks the substring in Messages")

        // The demo store lists "Studio Headphones" as an output; Return switches to it and shows progress in the submenu.
        let outputWindow = hostedPanel(PopoverView(store: store, preview: true, initialQuery: "studio head", focusSearch: true, shelf: shelf))
        defer { SideSubmenu.shared.close(); outputWindow.orderOut(nil) }
        try pressReturn(in: outputWindow)
        XCTAssertEqual(SideSubmenu.shared.selection, "search:output:headphones")
    }
}
