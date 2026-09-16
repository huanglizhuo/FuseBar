import XCTest
@testable import FuseBar

final class ApplicationShelfTests: XCTestCase {
    func testCompactGridBoundaryAndOverflowSlot() {
        let apps = (0..<13).map { ShelfApplication(id: "app.\($0)", name: "App \($0)", url: nil, running: true) }
        XCTAssertEqual(ApplicationShelfModel.compact(Array(apps.prefix(6))).apps.count, 6)
        let exactlyTwoRows = ApplicationShelfModel.compact(Array(apps.prefix(12)))
        XCTAssertEqual(exactlyTwoRows.apps.count, 12)
        XCTAssertFalse(exactlyTwoRows.overflow)
        let overflow = ApplicationShelfModel.compact(apps)
        XCTAssertEqual(overflow.apps.count, 11)
        XCTAssertTrue(overflow.overflow)
        XCTAssertEqual(overflow.apps.last?.id, "app.10")
    }

    func testCompactGridExcludesStoppedAppsAndDuplicateProcesses() {
        let active = ShelfApplication(id: "active", name: "Active", url: nil, running: true)
        let stopped = ShelfApplication(id: "stopped", name: "Stopped", url: nil, running: false)
        XCTAssertEqual(ApplicationShelfModel.compact([active, stopped, active]).apps, [active])
        XCTAssertFalse(ApplicationShelfModel.compact([]).overflow)
    }

    func testPinsKeepFirstOccurrenceAndOrder() {
        XCTAssertEqual(ApplicationShelfModel.normalizedPins(["b", "", "a", "b", "c"]), ["b", "a", "c"])
    }

    func testSearchTrimsWhitespaceAndMatchesNameOrIdentifier() {
        let apps = [ShelfApplication(id: "org.test.editor", name: "编辑器", url: nil, running: false),
                    ShelfApplication(id: "com.apple.finder", name: "Finder", url: nil, running: true)]
        XCTAssertEqual(ApplicationShelfModel.visible(apps, query: "  FINDER  ").map(\.id), ["com.apple.finder"])
        XCTAssertEqual(ApplicationShelfModel.visible(apps, query: "editor").map(\.name), ["编辑器"])
        XCTAssertTrue(ApplicationShelfModel.visible(apps, query: "not-installed").isEmpty)
    }

    func testUnavailableFavoriteSurvivesAndDuplicateProcessesCollapse() {
        let unavailable = ShelfApplication(id: "missing.app", name: "Missing", url: nil, running: false)
        let running = ShelfApplication(id: "running.app", name: "Running", url: URL(fileURLWithPath: "/Applications/Running.app"), running: true)
        XCTAssertEqual(ApplicationShelfModel.visible([unavailable, running, running], query: "  "), [unavailable, running])
    }

    @MainActor func testPinsPersistWithoutModifyingOtherPreferences() throws {
        let suite = "FuseBarTests.Shelf.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "showBattery")
        let shelf = ApplicationShelf(defaults: defaults)
        let missing = ShelfApplication(id: "test.fusebar.missing", name: "Missing", url: nil, running: false)
        shelf.togglePin(missing)
        let restored = ApplicationShelf(defaults: defaults)
        restored.refresh()
        XCTAssertEqual(restored.favorites.map(\.id), [missing.id])
        XCTAssertNil(restored.favorites.first?.url)
        restored.togglePin(missing)
        XCTAssertEqual(defaults.stringArray(forKey: "pinnedApplications"), [])
        XCTAssertFalse(defaults.bool(forKey: "showBattery"))
    }
}
