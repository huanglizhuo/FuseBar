import SwiftUI
import XCTest
@testable import FuseBar

final class ApplicationShelfTests: XCTestCase {
    func testHomeOrdersRunningAppsByRecencyWithoutDuplicates() {
        let editor = ShelfApplication(id: "editor", name: "Editor", url: nil, running: true)
        let browser = ShelfApplication(id: "browser", name: "Browser", url: nil, running: true)
        let stopped = ShelfApplication(id: "stopped", name: "Stopped", url: nil, running: false)
        let recent = ["browser", "gone", "editor", "browser"]
        XCTAssertEqual(ApplicationShelfModel.home(running: [editor, browser, stopped], recentIDs: recent).map(\.id), ["browser", "editor"])
        XCTAssertEqual(ApplicationShelfModel.recent([editor, browser, stopped], ids: ["browser"]).map(\.id), ["browser", "editor", "stopped"])
    }

    func testAppPanelWasOpenedFromTakesLastVisibleSlot() {
        let apps = (0..<14).map { ShelfApplication(id: "app\($0)", name: "App \($0)", url: nil, running: true) }
        let recent = apps.map(\.id)
        let home = ApplicationShelfModel.home(running: apps, recentIDs: recent, frontmostID: "app0")
        XCTAssertEqual(home.count, 12)
        XCTAssertEqual(home.first?.id, "app1")
        XCTAssertEqual(home.last?.id, "app0")
        XCTAssertEqual(ApplicationShelfModel.home(running: Array(apps.prefix(3)), recentIDs: recent, frontmostID: "app0").map(\.id),
                       ["app1", "app2", "app0"])
        XCTAssertEqual(ApplicationShelfModel.home(running: Array(apps.prefix(2)), recentIDs: recent, frontmostID: "gone").map(\.id),
                       ["app0", "app1"])
    }

    @MainActor func testCommandDigitOpensGridSlotWhileSearchIsFocused() throws {
        let suite = "FuseBarTests.Grid.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let apps = ["one", "two", "three"].map {
            ShelfApplication(id: "test.\($0)", name: $0, url: URL(fileURLWithPath: "/Applications/\($0).app"), running: true)
        }
        let shelf = ApplicationShelf(defaults: defaults, readApplications: { apps })
        shelf.refresh()
        let deadline = Date().addingTimeInterval(2)
        while shelf.running.count < 3 && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        var opened: [URL] = []
        let view = PopoverView(store: StatusStore(defaults: defaults, demo: true), preview: true, focusSearch: true,
                               onOpenApplication: { opened.append($0) }, shelf: shelf)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 600), styleMask: .titled, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                                    windowNumber: window.windowNumber, context: nil, characters: "2",
                                                    charactersIgnoringModifiers: "2", isARepeat: false, keyCode: 19))
        XCTAssertTrue(window.performKeyEquivalent(with: event))
        XCTAssertEqual(opened, [apps[1].url!])
    }

    @MainActor func testRecentUsePersistsAndIgnoresFuseBarAndRefresh() throws {
        let suite = "FuseBarTests.Recency.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shelf = ApplicationShelf(defaults: defaults)
        shelf.recordRecentApplication("editor")
        shelf.recordRecentApplication("browser")
        shelf.recordRecentApplication("editor")
        shelf.recordRecentApplication(Bundle.main.bundleIdentifier!)
        shelf.recordRecentApplication("")
        shelf.refresh()
        XCTAssertEqual(shelf.recentIDs, ["editor", "browser"])
        XCTAssertEqual(ApplicationShelf(defaults: defaults).recentIDs, ["editor", "browser"])
        for index in 0..<110 { shelf.recordRecentApplication("app.\(index)") }
        XCTAssertEqual(shelf.recentIDs.count, 100)
        XCTAssertEqual(shelf.recentIDs.first, "app.109")
    }

    @MainActor func testInstalledCatalogRefreshesOnlyOnDemandAfterExpiry() throws {
        let suite = "FuseBarTests.Catalog.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date(timeIntervalSince1970: 0)
        // Each scan changes the catalog, representing an install and a removal.
        let scans = CatalogScans()
        let shelf = ApplicationShelf(defaults: defaults, readInstalledApplications: { scans.read() }, now: { date })
        func awaitCatalog(_ id: String) {
            let deadline = Date().addingTimeInterval(2)
            while shelf.installed.first?.id != id && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            XCTAssertEqual(shelf.installed.first?.id, id)
        }
        shelf.discoverApplications()
        awaitCatalog("app1")
        date.addTimeInterval(59)
        shelf.discoverApplications()
        XCTAssertEqual(shelf.installed.first?.id, "app1")
        date.addTimeInterval(1)
        shelf.discoverApplications()
        awaitCatalog("app2")
        shelf.invalidateInstalledApplications()
        awaitCatalog("app3")
    }

    @MainActor func testInvalidationDuringCatalogScanSchedulesOneFollowUp() {
        let scans = CatalogScans()
        let entered = expectation(description: "Initial scan started")
        let release = DispatchSemaphore(value: 0)
        let shelf = ApplicationShelf(readInstalledApplications: {
            let result = scans.read()
            if result.first?.id == "app1" {
                entered.fulfill()
                _ = release.wait(timeout: .now() + 2)
            }
            return result
        })
        shelf.discoverApplications()
        wait(for: [entered], timeout: 1)
        shelf.invalidateInstalledApplications()
        shelf.invalidateInstalledApplications()
        release.signal()
        let deadline = Date().addingTimeInterval(2)
        while shelf.installed.first?.id != "app2" && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        XCTAssertEqual(shelf.installed.first?.id, "app2")
        XCTAssertEqual(scans.readCount, 2)
    }

    @MainActor func testActivationUpdatesSearchOrderWithoutReadingMetadata() throws {
        let suite = "FuseBarTests.Activation.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let scans = CatalogScans()
        let apps = ["one", "two"].map { ShelfApplication(id: $0, name: $0, url: nil, running: true) }
        let shelf = ApplicationShelf(defaults: defaults, readApplications: { _ = scans.read(); return apps })
        shelf.refresh()
        let deadline = Date().addingTimeInterval(2)
        while shelf.running.count != 2 && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        let reads = scans.readCount
        shelf.recordActivation("two")
        XCTAssertEqual(shelf.frontmostID, "two")
        XCTAssertEqual(shelf.searchable.map(\.id), ["two", "one"])
        XCTAssertEqual(scans.readCount, reads)
    }

    @MainActor func testForceQuitDefaultsToCancelAndCancelDoesNotTerminate() {
        let store = StatusStore(demo: true)
        let view = PopoverView(store: store, preview: true)
        let app = ShelfApplication(id: "test", name: "Unsaved Editor", url: nil, running: true)
        var terminated = false
        view.confirmForceQuit(app, runAlert: { alert in
            XCTAssertTrue(alert.messageText.contains(app.name))
            XCTAssertFalse(alert.informativeText.isEmpty)
            XCTAssertEqual(alert.buttons.first?.keyEquivalent, "\r")
            XCTAssertTrue(alert.window.defaultButtonCell === alert.buttons.first?.cell)
            XCTAssertEqual(alert.buttons.last?.keyEquivalent, "")
            XCTAssertEqual(alert.buttons.first?.title, L("取消"))
            return .alertFirstButtonReturn
        }, terminate: { _ in terminated = true; return nil })
        XCTAssertFalse(terminated)
    }

    @MainActor func testForceQuitModalPreservesPopoverAndRestoresDismissal() {
        let popover = QuitTrackingPopover()
        let delegate = AppDelegate(popover: popover)
        delegate.installDismissalMonitors()
        defer { delegate.popoverDidClose(Notification(name: NSPopover.didCloseNotification)) }
        let alert = CancellingQuitAlert()
        alert.duringPresentation = {
            XCTAssertTrue(SystemPanelPresentation.shared.isPresenting)
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
            XCTAssertEqual(popover.closeRequests, 0)
        }
        XCTAssertEqual(SystemPanelPresentation.shared.run(alert), .alertFirstButtonReturn)
        XCTAssertFalse(SystemPanelPresentation.shared.isPresenting)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertEqual(popover.closeRequests, 1)
    }

    func testOrderNormalizationKeepsFirstOccurrence() {
        XCTAssertEqual(ApplicationShelfModel.normalizedOrder(["b", "", "a", "b", "c"]), ["b", "a", "c"])
    }

    func testSearchTrimsWhitespaceAndMatchesNameOrIdentifier() {
        let apps = [ShelfApplication(id: "org.test.editor", name: "编辑器", url: nil, running: false),
                    ShelfApplication(id: "com.apple.finder", name: "Finder", url: nil, running: true)]
        XCTAssertEqual(ApplicationShelfModel.visible(apps, query: "  FINDER  ").map(\.id), ["com.apple.finder"])
        XCTAssertEqual(ApplicationShelfModel.visible(apps, query: "editor").map(\.name), ["编辑器"])
        XCTAssertTrue(ApplicationShelfModel.visible(apps, query: "not-installed").isEmpty)
    }

    func testDuplicateProcessesCollapseInSearchableList() {
        let running = ShelfApplication(id: "running.app", name: "Running", url: URL(fileURLWithPath: "/Applications/Running.app"), running: true)
        let installed = ShelfApplication(id: "running.app", name: "Running", url: URL(fileURLWithPath: "/Applications/Running.app"), running: false)
        XCTAssertEqual(ApplicationShelfModel.visible([running, installed, running], query: "  "), [running])
    }
}

private final class CatalogScans: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var readCount: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }
    func read() -> [ShelfApplication] {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return [ShelfApplication(id: "app\(count)", name: "App", url: nil, running: false)]
    }
}

@MainActor private final class QuitTrackingPopover: NSPopover {
    var closeRequests = 0
    override func performClose(_ sender: Any?) { closeRequests += 1 }
}

@MainActor private final class CancellingQuitAlert: NSAlert {
    var duringPresentation: (() -> Void)?
    override func runModal() -> NSApplication.ModalResponse {
        duringPresentation?()
        return .alertFirstButtonReturn
    }
}
