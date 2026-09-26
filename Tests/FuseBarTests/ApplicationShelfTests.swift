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
