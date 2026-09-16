import CoreAudio
import Foundation

struct AudioOutput: Identifiable, Equatable {
    let id: String // CoreAudio UID, not a reusable numeric device ID.
    let name: String
    let selected: Bool
}

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
        let deviceName = nameResult == noErr ? (name?.takeRetainedValue() as String? ?? L("声音输出")) : L("声音输出")
        let properties = volumeProperties(device)
        let volumes = properties.compactMap { scalar(device, $0, initial: Float(0)) }
        let mute: UInt32? = scalar(device, address(kAudioDevicePropertyMute), initial: UInt32(0))
        let volume = volumes.isEmpty ? nil : min(1, max(0, volumes.reduce(0, +) / Float(volumes.count)))
        return SoundStatus(available: true, deviceName: deviceName, volume: volume,
                           muted: mute.map { $0 != 0 },
                           canSetVolume: !properties.isEmpty && properties.allSatisfy { isSettable(device, $0) },
                           canSetMute: mute != nil && isSettable(device, address(kAudioDevicePropertyMute)),
                           deviceUID: text(device, selector: kAudioDevicePropertyDeviceUID))
    }

    private static func text(_ device: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var property = address(selector, scope: kAudioObjectPropertyScopeGlobal)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private static func outputDevices() -> [AudioObjectID] {
        var property = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let result = devices.withUnsafeMutableBytes { AudioObjectGetPropertyData(system, &property, 0, nil, &size, $0.baseAddress!) }
        guard result == noErr else { return [] }
        return devices.prefix(Int(size) / MemoryLayout<AudioObjectID>.size).filter {
            scalar($0, address(kAudioDevicePropertyDeviceCanBeDefaultDevice), initial: UInt32(0)) == 1
        }
    }

    static func outputs() -> [AudioOutput] {
        let selected = output()
        return outputDevices().compactMap { device in
            guard let uid = text(device, selector: kAudioDevicePropertyDeviceUID) else { return nil }
            return AudioOutput(id: uid, name: text(device, selector: kAudioObjectPropertyName) ?? L("声音输出"), selected: selected == device)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func selectOutput(uid: String) -> String? {
        guard let device = outputDevices().first(where: { text($0, selector: kAudioDevicePropertyDeviceUID) == uid }) else {
            return L("输出设备已断开，请刷新后重试。")
        }
        var property = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard isSettable(system, property) else { return L("系统不允许切换输出，请打开声音设置。") }
        var value = device
        guard AudioObjectSetPropertyData(system, &property, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value) == noErr else {
            return L("无法切换输出设备，请刷新后重试。")
        }
        guard output() == device else { return L("系统尚未确认输出切换，请刷新查看当前设备。") }
        return nil
    }

    static func setMuted(_ muted: Bool) -> String? {
        guard let device = output() else { return L("输出设备已断开。") }
        var property = address(kAudioDevicePropertyMute)
        guard isSettable(device, property) else { return L("此设备不支持软件静音，请使用设备自身控制。") }
        var value: UInt32 = muted ? 1 : 0
        guard AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr,
              scalar(device, property, initial: UInt32(0)) == value else {
            return L("设备未确认静音状态，请刷新后重试。")
        }
        return nil
    }

    static func setVolume(_ volume: Float, expectedUID: String? = nil) -> String? {
        guard let device = output() else { return L("输出设备已断开。") }
        if let expectedUID, text(device, selector: kAudioDevicePropertyDeviceUID) != expectedUID {
            return L("输出设备已切换，请在新设备上重新调整音量。")
        }
        let properties = volumeProperties(device)
        guard !properties.isEmpty && properties.allSatisfy({ isSettable(device, $0) }) else {
            return L("这个输出设备不支持软件音量控制，请在设备上调整。")
        }
        for var property in properties {
            var value = min(1, max(0, volume))
            guard AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float>.size), &value) == noErr else {
                return L("无法调整音量，输出设备可能已发生变化。")
            }
        }
        return nil
    }
}
