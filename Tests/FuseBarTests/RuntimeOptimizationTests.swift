import Foundation
import Testing
@testable import FuseBar

struct RuntimeOptimizationTests {
    @Test func fallbackKeepsWirelessFreshWithoutPollingBatteryAndSoundEveryTick() {
        for tick in 1..<10 {
            #expect(StatusReadDomains.fallback(tick: tick) == [.wifi, .bluetooth])
        }
        #expect(StatusReadDomains.fallback(tick: 0) == .all)
        #expect(StatusReadDomains.fallback(tick: 1, batteryNotificationsAvailable: false) == [.battery, .wifi, .bluetooth])
    }

    @MainActor @Test func listRefreshDoesNotBlockSelectionOrOverwriteItsResult() async throws {
        let reader = BlockedOutputReader()
        let store = StatusStore(startMonitoring: false, readAudioChoices: { reader.read() }, selectOutput: { _ in nil })
        defer { reader.gate.signal(); store.stop() }
        store.refreshAudioOutputs()
        try await eventually { reader.reads == 1 }
        #expect(store.audioOutputsRefreshing)
        #expect(!store.audioBusy)
        store.selectAudioOutput(AudioOutput(id: "new", name: "New", selected: false))
        try await eventually { reader.reads == 2 && !store.audioBusy }
        #expect(store.audioOutputs.first?.id == "new")
        reader.gate.signal()
        try await eventually { !store.audioOutputsRefreshing }
        #expect(store.audioOutputs.first?.id == "new")
    }

    @MainActor private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition(), "Background operation failed to settle")
    }
}

private final class BlockedOutputReader: @unchecked Sendable {
    let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    var reads: Int { lock.withLock { count } }
    func read() -> [AudioOutput] {
        let first = lock.withLock { count += 1; return count == 1 }
        if first { _ = gate.wait(timeout: .now() + 3) }
        return [AudioOutput(id: first ? "old" : "new", name: "Output", selected: true)]
    }
}
