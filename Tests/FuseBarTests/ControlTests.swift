import XCTest
import Testing
@testable import FuseBar

final class ControlTests: XCTestCase {
    func testAuthorizedButRedactedNetworkNameDoesNotRequestPermissionAgain() {
        let wifi = WiFiStatus(connection: .connected, name: nil)
        XCTAssertFalse(wifi.shouldOfferNameAuthorization(.allowed))
        XCTAssertTrue(wifi.shouldOfferNameAuthorization(.notRequested))
        XCTAssertFalse(WiFiStatus(connection: .connected, name: "Home").shouldOfferNameAuthorization(.notRequested))
        XCTAssertFalse(WiFiStatus(connection: .off).shouldOfferNameAuthorization(.notRequested))
    }

    @MainActor func testAudioListenerRegistrationAndCleanup() async throws {
        let monitor = AudioChangeMonitor(changed: {})
        monitor.start()
        for _ in 0..<200 {
            if monitor.registeredPropertyCount > 0 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
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

// Cached device names must disappear as soon as access/power is lost. These
// fixtures never create a Bluetooth manager or scan the user's networks.
@MainActor
struct DeviceMenuPrivacyTests {
    @Test func bluetoothCachedNamesAreClearedWhenAccessIsRevokedOrPowerIsOff() {
        for state in [BluetoothState.denied, .permissionRequired, .off, .unavailable, .unknown] {
            let controller = BluetoothPanelStore(preview: true)
            #expect(!controller.devices.isEmpty)
            controller.refresh(state: state)
            #expect(controller.devices.isEmpty)
            #expect(!controller.busy)
        }
    }

    @Test func closingWiFiMenuClearsCachedNetworkNamesAndPendingPresentation() {
        let controller = WiFiPanelStore(preview: true)
        #expect(!controller.networks.isEmpty)
        controller.invalidate()
        #expect(controller.networks.isEmpty)
        #expect(controller.connectingID == nil)
        #expect(!controller.busy)
        #expect(controller.message.isEmpty)
    }
}

@MainActor
struct ResponsivenessTests {
    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition(), "Background operation failed to settle")
    }

    @Test func audioObservationDoesNotBlockMainAndCoalescesDeviceBursts() async throws {
        let client = SlowAudioObservationClient()
        let monitor = AudioChangeMonitor(changed: {}, client: client)
        defer { client.gate.signal(); monitor.stop() }
        monitor.start()
        try await eventually { client.installs == 1 }
        #expect(!client.usedMain)
        #expect(monitor.registeredPropertyCount == 0) // Worker still deliberately blocked.
        client.gate.signal()
        try await eventually { monitor.registeredPropertyCount == 3 }
        let firstCallback = try #require(client.callback)
        for _ in 0..<100 { firstCallback(true) }
        try await eventually { client.installs == 2 }
        #expect(client.cancels == 1)
        monitor.stop()
        firstCallback(true) // Already queued callbacks must not resurrect stopped listeners.
        try await eventually { client.cancels == 2 }
        try await Task.sleep(for: .milliseconds(80))
        #expect(client.installs == 2)
        #expect(monitor.registeredPropertyCount == 0)
    }

    @Test func slowVolumeWriteKeepsOnlyLatestValue() async throws {
        let sink = SlowVolumeSink()
        let writer = LatestVolumeWriter(write: { sink.write($0) }, completed: { _ in })
        defer { sink.gate.signal() }
        writer.submit(VolumeWriteRequest(value: 0.1, deviceUID: "one"))
        try await eventually { sink.values.count == 1 }
        for index in 0..<250 { writer.submit(VolumeWriteRequest(value: Double(index) / 250, deviceUID: "one")) }
        #expect(sink.values.count == 1)
        sink.gate.signal()
        try await eventually { sink.values.count == 2 }
        #expect(sink.values == [0.1, 249.0 / 250])
    }

    @Test func outputSwitchDiscardsPendingVolumeAndStaleCompletion() async throws {
        let sink = SlowVolumeSink()
        var completions = 0
        let writer = LatestVolumeWriter(write: { sink.write($0) }, completed: { _ in completions += 1 })
        defer { sink.gate.signal() }
        writer.submit(VolumeWriteRequest(value: 0.1, deviceUID: "old"))
        try await eventually { sink.values.count == 1 }
        writer.submit(VolumeWriteRequest(value: 0.9, deviceUID: "old"))
        writer.cancelPending()
        sink.gate.signal()
        try await Task.sleep(for: .milliseconds(100))
        #expect(sink.values == [0.1])
        #expect(completions == 0)
        writer.submit(VolumeWriteRequest(value: 0.3, deviceUID: "new"))
        try await eventually { completions == 1 }
        #expect(sink.values == [0.1, 0.3])
    }

    @Test func applicationMetadataReadsAreBackgroundAndStaleResultsAreDiscarded() async throws {
        let suite = "FuseBarTests.SlowShelf.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let source = SlowApplicationReader()
        let shelf = ApplicationShelf(defaults: defaults, readApplications: { pins, _ in source.read(pins) })
        defer { source.gate.signal(); shelf.stop() }
        let app = ShelfApplication(id: "test.slow", name: "Slow", url: nil, running: false)
        shelf.togglePin(app)
        try await eventually { source.reads == 1 }
        #expect(!source.usedMain)
        #expect(shelf.favorites.first?.id == app.id)
        shelf.togglePin(app) // Remove while the original read is blocked.
        for _ in 0..<100 { shelf.refresh() }
        source.gate.signal()
        try await eventually { source.reads == 2 }
        try await Task.sleep(for: .milliseconds(30))
        #expect(source.reads == 2)
        #expect(shelf.favorites.isEmpty)
    }
}

struct BottomIndicatorTests {
    @Test func numberModesShowChosenPercentage() {
        var preferences = IndicatorPreferences()
        preferences.bottomIndicator = .batteryLevel
        #expect(StatusSnapshot.normal.bottomNumber(preferences) == "82")
        preferences.bottomIndicator = .volumeLevel
        #expect(StatusSnapshot.normal.bottomNumber(preferences) == "42")
    }

    @Test func numberModeFallsBackToDefaultPipelineWhenMetricUnavailable() {
        var preferences = IndicatorPreferences()
        var desktop = StatusSnapshot.normal
        desktop.battery.availability = .unavailable
        preferences.bottomIndicator = .batteryLevel
        #expect(desktop.bottomNumber(preferences) == nil)

        var noVolume = StatusSnapshot.normal
        noVolume.sound.available = false
        noVolume.sound.volume = nil
        preferences.bottomIndicator = .volumeLevel
        #expect(noVolume.bottomNumber(preferences) == nil)

        var hidden = IndicatorPreferences()
        hidden.sound = false
        hidden.bottomIndicator = .volumeLevel
        #expect(StatusSnapshot.normal.bottomNumber(hidden) == nil)
        hidden.battery = false
        hidden.bottomIndicator = .batteryLevel
        #expect(StatusSnapshot.normal.bottomNumber(hidden) == nil)
    }

    @Test func defaultModeKeepsAlertAndDotPipeline() {
        #expect(StatusSnapshot.normal.bottomNumber(IndicatorPreferences()) == nil)
        var critical = StatusSnapshot.normal
        critical.battery.level = 7
        #expect(critical.bottomNumber(IndicatorPreferences()) == nil)
    }

    @Test func storedRawValuesRoundTrip() {
        #expect(BottomIndicator(rawValue: "volumeLevel") == .volumeLevel)
        #expect(BottomIndicator(rawValue: "stale") == nil)
        #expect(BottomIndicator.allCases.map(\.rawValue) == ["status", "batteryLevel", "volumeLevel"])
    }
}

struct BatteryTintTests {
    @Test func ringTintFollowsSystemBatteryColors() {
        var battery = BatteryStatus(availability: .available, level: 82)
        #expect(battery.systemTint == .none)          // Plain level: macOS keeps label color.
        battery.charging = true
        #expect(battery.systemTint == .charging)      // Charging: green, even below 10%.
        battery.charging = false
        battery.level = 9
        #expect(battery.systemTint == .critical)      // Critical on battery power: red.
        battery.externalPower = true
        #expect(battery.systemTint == .none)          // Plugged in: no longer critical.
        battery.externalPower = false
        battery.level = 15
        #expect(battery.systemTint == .none)          // Merely low: macOS does not tint red yet.
    }

    @Test func unknownOrMissingBatteryNeverTints() {
        #expect(BatteryStatus().systemTint == .none)
        var missing = BatteryStatus()
        missing.availability = .unavailable
        #expect(missing.systemTint == .none)
        var critical = BatteryStatus(availability: .available, level: 5)
        critical.charging = true
        #expect(critical.systemTint == .charging)
    }
}

private final class SlowAudioObservationClient: AudioObservationClient, @unchecked Sendable {
    let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    private var removed = 0
    private var main = false
    private var listener: (@Sendable (Bool) -> Void)?
    var installs: Int { lock.withLock { count } }
    var cancels: Int { lock.withLock { removed } }
    var usedMain: Bool { lock.withLock { main } }
    var callback: (@Sendable (Bool) -> Void)? { lock.withLock { listener } }
    func install(on queue: DispatchQueue, changed: @escaping @Sendable (Bool) -> Void) -> AudioListenerSession {
        let first = lock.withLock { count += 1; main = main || Thread.isMainThread; listener = changed; return count == 1 }
        if first { _ = gate.wait(timeout: .now() + 2) }
        return AudioListenerSession(count: 3) { self.lock.withLock { self.removed += 1 } }
    }
}

private final class SlowVolumeSink: @unchecked Sendable {
    let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var writes: [Double] = []
    var values: [Double] { lock.withLock { writes } }
    func write(_ request: VolumeWriteRequest) -> String? {
        let first = lock.withLock { writes.append(request.value); return writes.count == 1 }
        if first { _ = gate.wait(timeout: .now() + 2) }
        return nil
    }
}

private final class SlowApplicationReader: @unchecked Sendable {
    let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    private var main = false
    var reads: Int { lock.withLock { count } }
    var usedMain: Bool { lock.withLock { main } }
    func read(_ pins: [String]) -> [ShelfApplication] {
        let first = lock.withLock { count += 1; main = main || Thread.isMainThread; return count == 1 }
        if first { _ = gate.wait(timeout: .now() + 2) }
        return pins.map { ShelfApplication(id: $0, name: "Resolved", url: nil, running: false) }
    }
}
