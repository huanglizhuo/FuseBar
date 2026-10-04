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

    @MainActor private func press(_ keyCode: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags = [], in window: NSWindow) throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                                    windowNumber: window.windowNumber, context: nil, characters: characters,
                                                    charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
        window.sendEvent(event)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    @MainActor private func pressReturn(in window: NSWindow) throws { try press(36, "\r", in: window) }

    /// Running Messages then Safari, as the shelf lists them by recent use.
    @MainActor private func messagesAndSafari(_ defaults: UserDefaults) -> (ApplicationShelf, [ShelfApplication]) {
        let apps = [("com.apple.MobileSMS", "Messages"), ("com.apple.Safari", "Safari")].map {
            ShelfApplication(id: $0.0, name: $0.1, url: URL(fileURLWithPath: "/Applications/\($0.1).app"), running: true)
        }
        let shelf = ApplicationShelf(defaults: defaults, readApplications: { apps })
        shelf.refresh()
        let deadline = Date().addingTimeInterval(2)
        while shelf.running.count < 2 && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        return (shelf, apps)
    }

    @MainActor func testArrowKeysMoveTheSelectionThatReturnOpens() throws {
        let suite = "FuseBarTests.SearchKeys.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let (shelf, apps) = messagesAndSafari(defaults)
        var opened: [URL] = []
        // "sa" lists Safari (prefix) above Messages (substring).
        let window = hostedPanel(PopoverView(store: StatusStore(defaults: defaults, demo: true), preview: true, initialQuery: "sa",
                                             focusSearch: true, onOpenApplication: { opened.append($0) }, shelf: shelf))
        defer { window.orderOut(nil) }
        XCTAssertTrue(window.firstResponder is NSTextView, "Search is focused")
        let arrow: NSEvent.ModifierFlags = [.numericPad, .function]
        try press(125, String(UnicodeScalar(UInt16(NSDownArrowFunctionKey))!), arrow, in: window)
        try pressReturn(in: window)
        XCTAssertEqual(opened, [apps[0].url!], "↓ selects Messages, the second result")
        try press(126, String(UnicodeScalar(UInt16(NSUpArrowFunctionKey))!), arrow, in: window)
        try pressReturn(in: window)
        XCTAssertEqual(opened.last, apps[1].url!, "↑ returns to Safari")
        XCTAssertTrue(window.firstResponder is NSTextView, "Typing can continue after moving the selection")
    }

    @MainActor func testReturnRunsBestResultAndDeviceResultsOpenTheirSubmenu() throws {
        let suite = "FuseBarTests.SearchActions.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let (shelf, apps) = messagesAndSafari(defaults)
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

    @MainActor private func keyEvent(_ keyCode: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags = [],
                                     in window: NSWindow? = nil) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                       windowNumber: window?.windowNumber ?? 0, context: nil, characters: characters,
                                       charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
    }

    @MainActor func testSearchKeyMappingLeavesModifiedKeysAlone() throws {
        let arrow: NSEvent.ModifierFlags = [.numericPad, .function]
        XCTAssertEqual(SearchKeys.key(for: try keyEvent(126, "", arrow)), .up)
        XCTAssertEqual(SearchKeys.key(for: try keyEvent(125, "", arrow)), .down)
        XCTAssertEqual(SearchKeys.key(for: try keyEvent(36, "\r")), .open)
        XCTAssertEqual(SearchKeys.key(for: try keyEvent(76, "\u{3}", .numericPad)), .open, "Keypad Enter opens too")
        XCTAssertNil(SearchKeys.key(for: try keyEvent(125, "", arrow.union(.command))))
        XCTAssertNil(SearchKeys.key(for: try keyEvent(36, "\r", .shift)))
        XCTAssertNil(SearchKeys.key(for: try keyEvent(123, "", arrow)), "← and → stay with the field and input method")
    }

    @MainActor func testAppRoutesSearchKeysBeforeTheFieldEditor() throws {
        let suite = "FuseBarTests.SearchRouting.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let (shelf, apps) = messagesAndSafari(defaults)
        let popover = NSPopover()
        let delegate = AppDelegate(popover: popover)
        var opened: [URL] = []
        let controller = NSHostingController(rootView: PopoverView(store: StatusStore(defaults: defaults, demo: true), preview: true,
                                                                   initialQuery: "sa", focusSearch: true,
                                                                   onOpenApplication: { opened.append($0) },
                                                                   searchKeys: delegate.searchKeys, shelf: shelf))
        popover.contentViewController = controller
        // Routing only needs the window that holds the panel's view; a plain window stands in for the popover.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 640), styleMask: .titled, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = controller.view
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(window.firstResponder is NSTextView, "Search is focused")
        let arrow: NSEvent.ModifierFlags = [.numericPad, .function]
        let down = String(UnicodeScalar(UInt16(NSDownArrowFunctionKey))!)
        XCTAssertTrue(delegate.routeSearchKey(try keyEvent(125, down, arrow, in: window)))
        XCTAssertTrue(delegate.routeSearchKey(try keyEvent(36, "\r", in: window)))
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(opened, [apps[0].url!], "↓ then Return opens Messages, consumed before any input method")
        XCTAssertFalse(delegate.routeSearchKey(try keyEvent(125, down, arrow.union(.command), in: window)), "⌘↓ is left alone")
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10), styleMask: .titled, backing: .buffered, defer: false)
        XCTAssertFalse(delegate.routeSearchKey(try keyEvent(125, down, arrow, in: other)), "Keys for other windows are left alone")
    }
}
