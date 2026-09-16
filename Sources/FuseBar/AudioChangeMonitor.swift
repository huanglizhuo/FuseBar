import CoreAudio
import Foundation

/// Observe the default output and its actual volume/mute channels. Polling remains a fallback.
@MainActor
final class AudioChangeMonitor {
    private struct Registration {
        let device: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }
    private var registrations: [Registration] = []
    var registeredPropertyCount: Int { registrations.count }
    private var active = false
    private let changed: () -> Void

    init(changed: @escaping () -> Void) { self.changed = changed }

    func start() {
        stop()
        active = true
        register(AudioObjectID(kAudioObjectSystemObject), AudioDevice.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal), rebind: true)
        if let device = AudioDevice.output() {
            for property in AudioDevice.volumeProperties(device) { register(device, property) }
            register(device, AudioDevice.address(kAudioDevicePropertyMute))
            register(device, AudioDevice.address(kAudioDevicePropertyDeviceIsAlive, scope: kAudioObjectPropertyScopeGlobal), rebind: true)
        }
    }

    private func register(_ device: AudioObjectID, _ address: AudioObjectPropertyAddress, rebind: Bool = false) {
        var address = address
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.active else { return }
                if rebind { self.start() }
                self.changed()
            }
        }
        if AudioObjectAddPropertyListenerBlock(device, &address, .main, block) == noErr {
            registrations.append(Registration(device: device, address: address, block: block))
        }
    }

    func stop() {
        active = false
        for var entry in registrations {
            AudioObjectRemovePropertyListenerBlock(entry.device, &entry.address, .main, entry.block)
        }
        registrations.removeAll()
    }
}
