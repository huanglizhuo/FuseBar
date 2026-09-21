import CoreAudio
import Foundation

struct AudioListenerSession {
    let count: Int
    let cancel: () -> Void
}

/// Installation and cancellation are called exclusively on the control queue the
/// caller designates, which must differ from the queue used for listener delivery.
protocol AudioObservationClient: Sendable {
    func install(on queue: DispatchQueue, changed: @escaping @Sendable (Bool) -> Void) -> AudioListenerSession
}

struct SystemAudioObservationClient: AudioObservationClient {
    func install(on queue: DispatchQueue, changed: @escaping @Sendable (Bool) -> Void) -> AudioListenerSession {
        var registrations: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
        func register(_ device: AudioObjectID, _ property: AudioObjectPropertyAddress, rebind: Bool = false) {
            var property = property
            let block: AudioObjectPropertyListenerBlock = { _, _ in changed(rebind) }
            if AudioObjectAddPropertyListenerBlock(device, &property, queue, block) == noErr {
                registrations.append((device, property, block))
            }
        }
        let system = AudioObjectID(kAudioObjectSystemObject)
        register(system, AudioDevice.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal), rebind: true)
        register(system, AudioDevice.address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal), rebind: true)
        if let device = AudioDevice.output() {
            for property in AudioDevice.volumeProperties(device) { register(device, property) }
            register(device, AudioDevice.address(kAudioDevicePropertyMute))
            register(device, AudioDevice.address(kAudioDevicePropertyDeviceIsAlive, scope: kAudioObjectPropertyScopeGlobal), rebind: true)
        }
        let installed = registrations
        return AudioListenerSession(count: installed.count) {
            for (device, address, block) in installed {
                var address = address
                AudioObjectRemovePropertyListenerBlock(device, &address, queue, block)
            }
        }
    }
}

/// All mutable fields below belong to the control queue. No synchronous hop to the
/// main thread. Listener blocks are delivered on a separate delivery queue, so
/// AudioObjectAdd/RemovePropertyListenerBlock never run on the queue CoreAudio
/// dispatches listeners to — removing a listener from its own delivery queue is
/// the classic CoreAudio self-join hang.
private final class AudioObservationWorker: @unchecked Sendable {
    private let deliveryQueue = DispatchQueue(label: "com.fusebar.audio-observation", qos: .utility)
    private let queue = DispatchQueue(label: "com.fusebar.audio-observation-state", qos: .utility)
    private let client: any AudioObservationClient
    private var session: AudioListenerSession?
    private var revision = 0
    private var active = false
    private var pending = false
    private var needsRebind = false
    private var report: (@Sendable (Int, Bool, Bool) -> Void)?

    init(client: any AudioObservationClient) { self.client = client }

    func start(report: @escaping @Sendable (Int, Bool, Bool) -> Void) {
        queue.async {
            self.active = true
            self.report = report
            self.bind(notify: false)
        }
    }

    func stop() {
        queue.async {
            self.active = false
            self.revision += 1
            self.pending = false
            self.needsRebind = false
            self.session?.cancel()
            self.session = nil
            self.report = nil
        }
    }

    private func bind(notify: Bool) {
        revision += 1
        let token = revision
        pending = false
        needsRebind = false
        session?.cancel()
        session = client.install(on: deliveryQueue) { [weak self] rebind in
            guard let self else { return }
            self.queue.async { self.receive(rebind: rebind, token: token) }
        }
        report?(session?.count ?? 0, notify, notify)
    }

    private func receive(rebind: Bool, token: Int) {
        guard active, token == revision else { return }
        needsRebind = needsRebind || rebind
        guard !pending else { return }
        pending = true
        queue.asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self] in
            guard let self, self.active, self.revision == token else { return }
            self.pending = false
            if self.needsRebind { self.bind(notify: true) }
            else { self.report?(self.session?.count ?? 0, true, false) }
        }
    }
}

@MainActor
final class AudioChangeMonitor {
    private let worker: AudioObservationWorker
    private var generation = 0
    private(set) var registeredPropertyCount = 0
    private let changed: () -> Void
    private let outputsChanged: () -> Void

    init(changed: @escaping () -> Void, outputsChanged: @escaping () -> Void = {},
         client: any AudioObservationClient = SystemAudioObservationClient()) {
        self.changed = changed
        self.outputsChanged = outputsChanged
        worker = AudioObservationWorker(client: client)
    }

    func start() {
        generation += 1
        let token = generation
        worker.start { [weak self] count, changed, outputsChanged in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.registeredPropertyCount = count
                if outputsChanged { self.outputsChanged() }
                if changed { self.changed() }
            }
        }
    }

    func stop() {
        generation += 1
        registeredPropertyCount = 0
        worker.stop()
    }

    deinit { worker.stop() }
}
