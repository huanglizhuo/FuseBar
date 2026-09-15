import CoreAudio
import Foundation

/// Reads the current output on each operation; never writes to a cached output device.
enum AudioDevice {
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeOutput,
                        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func scalar<T: Numeric>(_ device: AudioObjectID, _ property: AudioObjectPropertyAddress, initial: T) -> T? {
        var property = property
        guard AudioObjectHasProperty(device, &property) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let result = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(device, &property, 0, nil, &size, $0)
        }
        guard result == noErr else { return nil }
        return value
    }

    static func output() -> AudioObjectID? {
        let id = scalar(AudioObjectID(kAudioObjectSystemObject),
                        address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal), initial: AudioObjectID(0))
        return id == 0 ? nil : id
    }

    static func volumeProperties(_ device: AudioObjectID) -> [AudioObjectPropertyAddress] {
        let main = address(kAudioDevicePropertyVolumeScalar)
        if scalar(device, main, initial: Float(0)) != nil { return [main] }
        // Common stereo devices expose per-channel volume instead of a master property.
        return [UInt32(1), UInt32(2)].map { address(kAudioDevicePropertyVolumeScalar, element: $0) }
            .filter { scalar(device, $0, initial: Float(0)) != nil }
    }

    static func isSettable(_ device: AudioObjectID, _ property: AudioObjectPropertyAddress) -> Bool {
        var property = property
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &property, &settable) == noErr && settable.boolValue
    }

    static func read() -> SoundStatus {
        guard let device = output() else { return SoundStatus() }
        var nameProperty = address(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let nameResult = AudioObjectGetPropertyData(device, &nameProperty, 0, nil, &size, &name)
        let deviceName = nameResult == noErr ? (name?.takeRetainedValue() as String? ?? "声音输出") : "声音输出"
        let properties = volumeProperties(device)
        let volumes = properties.compactMap { scalar(device, $0, initial: Float(0)) }
        let mute: UInt32? = scalar(device, address(kAudioDevicePropertyMute), initial: UInt32(0))
        let volume = volumes.isEmpty ? nil : min(1, max(0, volumes.reduce(0, +) / Float(volumes.count)))
        return SoundStatus(available: true, deviceName: deviceName, volume: volume,
                           muted: mute.map { $0 != 0 },
                           canSetVolume: !properties.isEmpty && properties.allSatisfy { isSettable(device, $0) })
    }

    static func setVolume(_ volume: Float) -> String? {
        guard let device = output() else { return "输出设备已断开。" }
        let properties = volumeProperties(device)
        guard !properties.isEmpty && properties.allSatisfy({ isSettable(device, $0) }) else {
            return "这个输出设备不支持软件音量控制，请在设备上调整。"
        }
        for var property in properties {
            var value = min(1, max(0, volume))
            guard AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float>.size), &value) == noErr else {
                return "无法调整音量，输出设备可能已发生变化。"
            }
        }
        return nil
    }
}
