import Foundation
import CoreAudio
import Testing
@testable import FuseBar

@Suite(.serialized)
@MainActor
struct BluetoothControlTests {
    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(predicate(), "Bluetooth operation did not finish")
    }

    @Test func rowConnectsAndDisconnectsTheRequestedDevice() async throws {
        let client = FakeBluetoothClient()
        let store = BluetoothPanelStore(client: client, authorized: { true })
        store.refresh(state: .on)
        try await waitUntil { !store.busy }
        let device = try #require(store.devices.first)
        store.setConnected(device, connected: true, state: .on)
        #expect(store.pendingDeviceID == device.id)
        #expect(store.devices.first?.connected == false)
        try await waitUntil { !store.busy }
        #expect(store.devices.first?.connected == true)
        #expect(!store.failed)
        store.setConnected(try #require(store.devices.first), connected: false, state: .on)
        try await waitUntil { !store.busy }
        #expect(store.devices.first?.connected == false)
        #expect(client.requestedStates == [true, false])
    }

    @Test func failureStaysVisibleAndNeverMarksConnected() async throws {
        let client = FakeBluetoothClient(error: "connection failed")
        let store = BluetoothPanelStore(client: client, authorized: { true })
        store.refresh(state: .on)
        try await waitUntil { !store.busy }
        store.setConnected(try #require(store.devices.first), connected: true, state: .on)
        try await waitUntil { !store.busy }
        #expect(store.failed)
        #expect(store.message == "connection failed")
        #expect(store.devices.first?.connected == false)
        store.refresh(state: .on)
        try await waitUntil { !store.busy }
        #expect(store.message == "connection failed")
    }

    @Test func successfulCommandStillRequiresConfirmedReadback() async throws {
        let client = FakeBluetoothClient(changesState: false)
        let store = BluetoothPanelStore(client: client, authorized: { true })
        store.refresh(state: .on)
        try await waitUntil { !store.busy }
        store.setConnected(try #require(store.devices.first), connected: true, state: .on)
        try await waitUntil { !store.busy }
        #expect(store.failed)
        #expect(store.devices.first?.connected == false)
    }

    @Test func duplicateClickIsIgnoredAndPowerOffDiscardsLateResult() async throws {
        let client = FakeBluetoothClient(block: true)
        defer { client.release() }
        let store = BluetoothPanelStore(client: client, authorized: { true })
        store.refresh(state: .on)
        try await waitUntil { !store.busy }
        let device = try #require(store.devices.first)
        store.setConnected(device, connected: true, state: .on)
        try await waitUntil { client.requestedStates.count == 1 }
        store.setConnected(device, connected: true, state: .on)
        #expect(client.requestedStates == [true])
        store.refresh(state: .off)
        #expect(store.devices.isEmpty)
        #expect(store.pendingDeviceID == nil)
        client.release()
        try await waitUntil { client.finished }
        // Drain a fresh serialized read: the old completion must not repopulate first.
        try await Task.sleep(for: .milliseconds(30))
        #expect(store.devices.isEmpty)
        #expect(!store.busy)
    }

    @Test func forbiddenOrMissingDeviceCannotStartConnection() async throws {
        let client = FakeBluetoothClient()
        let store = BluetoothPanelStore(client: client, authorized: { true })
        store.refresh(state: .on)
        try await waitUntil { !store.busy }
        let device = try #require(store.devices.first)
        store.setConnected(device, connected: true, state: .denied)
        let missing = PairedBluetoothDevice(id: "missing", name: "Missing", connected: false)
        store.setConnected(missing, connected: true, state: .on)
        #expect(client.requestedStates.isEmpty)
    }
}

private final class FakeBluetoothClient: BluetoothDeviceControlling, @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private let error: String?
    private let changesState: Bool
    private let block: Bool
    private var connected = false
    private var requests: [Bool] = []
    private var done = false
    init(error: String? = nil, changesState: Bool = true, block: Bool = false) {
        self.error = error; self.changesState = changesState; self.block = block
    }
    var requestedStates: [Bool] { lock.withLock { requests } }
    var finished: Bool { lock.withLock { done } }
    func release() { gate.signal() }
    func read() -> [PairedBluetoothDevice]? {
        lock.withLock { [PairedBluetoothDevice(id: "00-11-22-33-44-55", name: "HC3", connected: connected, isAudioDevice: true)] }
    }
    func setConnected(address: String, connected: Bool) -> String? {
        lock.withLock { requests.append(connected) }
        if block { _ = gate.wait(timeout: .now() + 2) }
        return lock.withLock {
            if error == nil && changesState { self.connected = connected }
            done = true
            return error
        }
    }
}

struct BluetoothDeviceNameTests {
    @Test func systemAudioNameOverridesRemoteNameAndSurvivesDisconnectAndRestart() throws {
        let suite = "FuseBarTests.BluetoothNames.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = BluetoothDeviceNames(defaults: defaults)
        let address = "AA:BB:CC:DD:EE:FF"
        let output = AudioOutput(id: "aa-bb-cc-dd-ee-ff:output", name: "HC3", selected: true, transport: kAudioDeviceTransportTypeBluetooth)
        #expect(cache.resolve(addresses: [address], outputs: [output])["aa-bb-cc-dd-ee-ff"] == "HC3")
        let restarted = BluetoothDeviceNames(defaults: defaults)
        #expect(restarted.resolve(addresses: [address], outputs: [])["aa-bb-cc-dd-ee-ff"] == "HC3")
        #expect(restarted.resolve(addresses: [], outputs: []).isEmpty)
    }

    @Test func exactBluetoothOutputIdentityIsRequired() {
        for uid in ["aa-bb-cc-dd-ee-ff:input", "prefix-aa-bb-cc-dd-ee-ff:output", "aa-bb-cc-dd-ee:output", "aa-bb-cc-dd-ee-gg:output"] {
            #expect(BluetoothDeviceNames.audioAddress(AudioOutput(id: uid, name: "HC3", selected: false, transport: kAudioDeviceTransportTypeBluetooth)) == nil)
        }
        #expect(BluetoothDeviceNames.audioAddress(AudioOutput(id: "aa-bb-cc-dd-ee-ff:output", name: "HC3", selected: false, transport: kAudioDeviceTransportTypeUSB)) == nil)
    }

    @Test func renamedDeviceUpdatesCacheButAmbiguousNamesDoNotOverwriteIt() throws {
        let suite = "FuseBarTests.BluetoothNames.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = BluetoothDeviceNames(defaults: defaults)
        let address = "aa-bb-cc-dd-ee-ff"
        func output(_ name: String) -> AudioOutput { AudioOutput(id: address + ":output", name: name, selected: false, transport: kAudioDeviceTransportTypeBluetooth) }
        #expect(cache.resolve(addresses: [address], outputs: [output("HC3")])[address] == "HC3")
        #expect(cache.resolve(addresses: [address], outputs: [output("New Name")])[address] == "New Name")
        #expect(cache.resolve(addresses: [address], outputs: [output("A"), output("B")])[address] == "New Name")
    }
}

struct BluetoothAudioConnectionTests {
    private let address = "00-11-22-33-44-55"
    private var headset: PairedBluetoothDevice {
        PairedBluetoothDevice(id: address, name: "HC3", connected: false, isAudioDevice: true)
    }
    private var route: AudioOutput {
        AudioOutput(id: address + ":output", name: "HC3", selected: false, transport: kAudioDeviceTransportTypeBluetooth)
    }

    @Test func pairedHeadsetRemainsVisibleButKeyboardDoesNotAndLiveRouteIsNotDuplicated() {
        let keyboard = PairedBluetoothDevice(id: "aa-bb-cc-dd-ee-ff", name: "Keyboard", connected: false)
        let disconnected = AudioOutput.choices(outputs: [], paired: [headset, keyboard])
        #expect(disconnected.count == 1)
        #expect(disconnected.first?.name == "HC3")
        #expect(disconnected.first?.bluetoothAddress == address)
        #expect(disconnected.first?.selected == false)
        #expect(AudioOutput.choices(outputs: [route], paired: [headset, keyboard]) == [route])
    }

    @Test func waitsForMatchingRouteThenSelectsIt() {
        let client = FakeBluetoothClient()
        var polls = 0
        var chosen: [String] = []
        let unrelated = AudioOutput(id: "aa-bb-cc-dd-ee-ff:output", name: "HC3", selected: false, transport: kAudioDeviceTransportTypeBluetooth)
        let error = BluetoothAudioConnection.select(address: address, client: client, outputs: {
            polls += 1
            return polls < 3 ? [unrelated] : [unrelated, route]
        }, selectOutput: { chosen.append($0); return nil }, wait: {}, attempts: 4)
        #expect(error == nil)
        #expect(client.requestedStates == [true])
        #expect(polls == 3)
        #expect(chosen == [route.id])
    }

    @Test func connectedWithoutAudioRouteTimesOutWithoutSelectingAnything() {
        let client = FakeBluetoothClient()
        var selections = 0
        let error = BluetoothAudioConnection.select(address: address, client: client, outputs: { [] },
            selectOutput: { _ in selections += 1; return nil }, wait: {}, attempts: 2)
        #expect(error != nil)
        #expect(selections == 0)
        #expect(client.requestedStates == [true])
    }

    @Test func connectionErrorStopsBeforeAudioSelectionAndSelectionErrorIsPreserved() {
        let failed = FakeBluetoothClient(error: "connection failed")
        var selections = 0
        let error = BluetoothAudioConnection.select(address: address, client: failed, outputs: { [route] },
            selectOutput: { _ in selections += 1; return nil }, wait: {})
        #expect(error == "connection failed")
        #expect(selections == 0)
        let selectionError = BluetoothAudioConnection.select(address: address, client: FakeBluetoothClient(), outputs: { [route] },
            selectOutput: { _ in "route failed" }, wait: {})
        #expect(selectionError == "route failed")
    }

    @Test func unpairedDeviceNeverConnects() {
        let client = FakeBluetoothClient()
        let error = BluetoothAudioConnection.select(address: "aa-bb-cc-dd-ee-ff", client: client,
            outputs: { [route] }, selectOutput: { _ in nil }, wait: {})
        #expect(error != nil)
        #expect(client.requestedStates.isEmpty)
    }
}
