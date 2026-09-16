import XCTest
@testable import FuseBar

final class ControlTests: XCTestCase {
    func testAuthorizedButRedactedNetworkNameDoesNotRequestPermissionAgain() {
        let wifi = WiFiStatus(connection: .connected, name: nil)
        XCTAssertFalse(wifi.shouldOfferNameAuthorization(.allowed))
        XCTAssertTrue(wifi.shouldOfferNameAuthorization(.notRequested))
        XCTAssertFalse(WiFiStatus(connection: .connected, name: "Home").shouldOfferNameAuthorization(.notRequested))
        XCTAssertFalse(WiFiStatus(connection: .off).shouldOfferNameAuthorization(.notRequested))
    }

    @MainActor func testAudioListenerRegistrationAndCleanup() {
        let monitor = AudioChangeMonitor(changed: {})
        monitor.start()
        XCTAssertGreaterThan(monitor.registeredPropertyCount, 0)
        let count = monitor.registeredPropertyCount
        monitor.start()
        XCTAssertEqual(monitor.registeredPropertyCount, count)
        monitor.stop()
        XCTAssertEqual(monitor.registeredPropertyCount, 0)
    }

    func testNetworkGroupingKeepsCurrentFlagFromWeakerAccessPoint() {
        let weak = NearbyNetwork(id: "home:personal", name: "Home", signal: -80, security: .personal, connected: true)
        let strong = NearbyNetwork(id: "home:personal", name: "Home", signal: -40, security: .personal, connected: false)
        let other = NearbyNetwork(id: "other:open", name: "Other", signal: -30, security: .open, connected: false)
        let result = NearbyNetwork.ordered([other, weak, strong])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.id, weak.id)
        XCTAssertEqual(result.first?.signal, -40)
        XCTAssertEqual(result.first?.connected, true)
    }

    func testSameNameWithDifferentSecurityDoesNotMerge() {
        let open = NearbyNetwork(id: "home:open", name: "Home", signal: -40, security: .open, connected: false)
        let secure = NearbyNetwork(id: "home:personal", name: "Home", signal: -40, security: .personal, connected: false)
        XCTAssertEqual(NearbyNetwork.ordered([secure, open]), [open, secure])
        XCTAssertTrue(NearbyNetwork.ordered([]).isEmpty)
    }

    func testPinMovementAtBoundariesAndMissingIdentity() {
        XCTAssertEqual(ApplicationShelfModel.moving(["a", "b", "c"], id: "b", offset: -1), ["b", "a", "c"])
        XCTAssertEqual(ApplicationShelfModel.moving(["a", "b", "c"], id: "b", offset: 1), ["a", "c", "b"])
        XCTAssertEqual(ApplicationShelfModel.moving(["a", "b"], id: "a", offset: -1), ["a", "b"])
        XCTAssertEqual(ApplicationShelfModel.moving(["a", "b"], id: "b", offset: 1), ["a", "b"])
        XCTAssertEqual(ApplicationShelfModel.moving(["a"], id: "missing", offset: 1), ["a"])
    }

    @MainActor func testFileShortcutInvalidBookmarkFailsWithoutDeletingEntry() throws {
        let suite = "FuseBarTests.Files.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let entry = FileShortcut(id: UUID(), name: "Missing folder", bookmark: Data([0, 1, 2]))
        defaults.set(try JSONEncoder().encode([entry]), forKey: "fileShortcuts")
        let store = FileShortcuts(defaults: defaults)
        XCTAssertEqual(store.items.count, 1)
        store.open(entry)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.items.first?.id, entry.id)
        store.remove(entry)
        XCTAssertTrue(FileShortcuts(defaults: defaults).items.isEmpty)
    }
}
