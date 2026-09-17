import AppKit
import Carbon
import SwiftUI

struct ShortcutCombination: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var isValid: Bool {
        let allowed = UInt32(cmdKey | controlKey | optionKey | shiftKey)
        let flags = modifiers & allowed
        return keyCode < 128 && keyCode != 53 && !keyLabel.isEmpty &&
            modifiers == flags && flags.nonzeroBitCount >= 2 &&
            flags & UInt32(cmdKey | controlKey) != 0 &&
            !(keyCode == 12 && flags == UInt32(cmdKey | controlKey)) &&
            !(keyCode == 53 && flags == UInt32(cmdKey | optionKey))
    }
    var title: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyLabel
    }
    static func from(_ event: NSEvent) -> ShortcutCombination {
        var modifiers: UInt32 = 0
        for (flag, carbon): (NSEvent.ModifierFlags, Int) in [(.command, cmdKey), (.control, controlKey), (.option, optionKey), (.shift, shiftKey)] {
            if event.modifierFlags.contains(flag) { modifiers |= UInt32(carbon) }
        }
        let special: [UInt16: String] = [49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
            106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"]
        let label = special[event.keyCode] ?? (event.charactersIgnoringModifiers ?? "").uppercased()
        return ShortcutCombination(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}

@MainActor
final class GlobalShortcut: ObservableObject {
    static let shared = GlobalShortcut()
    @Published private(set) var combination: ShortcutCombination?
    @Published private(set) var error: String?
    @Published private(set) var active = false
    var onInvoke: (() -> Void)?
    private let defaults: UserDefaults
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var serial: UInt32 = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "quickOpenShortcut"),
           let saved = try? JSONDecoder().decode(ShortcutCombination.self, from: data), saved.isValid { combination = saved }
    }

    func start() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == 0x46555345 else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                guard id.id == owner.serial else { return OSStatus(eventNotHandledErr) }
                owner.onInvoke?()
                return noErr
            }
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { error = L("无法注册快捷键，请重试。"); return }
        if let combination { apply(combination) }
    }

    private func isSystemShortcut(_ value: ShortcutCombination) -> Bool {
        var entries: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&entries) == noErr,
              let entries = entries?.takeRetainedValue() as? [[String: Any]] else { return false }
        return entries.contains {
            ($0[kHISymbolicHotKeyEnabled as String] as? NSNumber)?.boolValue == true &&
            ($0[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value == value.keyCode &&
            ($0[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value == value.modifiers
        }
    }

    func apply(_ value: ShortcutCombination) {
        guard value.isValid else { error = L("请使用至少两个修饰键，并包含 ⌘ 或 ⌃。"); return }
        guard !isSystemShortcut(value) else { error = L("快捷键不可用或已被占用，原快捷键保持不变。"); return }
        if value == combination, active { error = nil; return }
        guard handler != nil else { error = L("无法注册快捷键，请重试。"); return }
        var candidate: EventHotKeyRef?
        let next = serial &+ 1
        let status = RegisterEventHotKey(value.keyCode, value.modifiers,
                                        EventHotKeyID(signature: 0x46555345, id: next), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &candidate)
        guard status == noErr, let candidate else {
            error = L("快捷键不可用或已被占用，原快捷键保持不变。")
            return
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate
        serial = next
        combination = value
        active = true
        error = nil
        defaults.set(try? JSONEncoder().encode(value), forKey: "quickOpenShortcut")
    }

    func clear() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil; combination = nil; active = false; error = nil
        defaults.removeObject(forKey: "quickOpenShortcut")
    }
    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil; active = false
    }
}

final class RecordingButton: NSButton {
    var receive: ((ShortcutCombination) -> Void)?
    var idleTitle = ""
    private(set) var recording = false
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { beginRecording() }
    override func accessibilityPerformPress() -> Bool { beginRecording(); return true }
    private func beginRecording() {
        recording = true
        title = L("按下快捷键，Esc 取消")
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else {
            if event.keyCode == 49 || event.keyCode == 36 { mouseDown(with: event) }
            else { super.keyDown(with: event) }
            return
        }
        recording = false
        title = idleTitle
        if event.keyCode != 53 { receive?(ShortcutCombination.from(event)) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
    override func resignFirstResponder() -> Bool {
        recording = false; title = idleTitle
        return super.resignFirstResponder()
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var shortcut: GlobalShortcut
    func makeNSView(context: Context) -> RecordingButton {
        let button = RecordingButton()
        button.bezelStyle = .rounded
        button.setAccessibilityLabel(L("快速打开快捷键"))
        return button
    }
    func updateNSView(_ button: RecordingButton, context: Context) {
        button.idleTitle = shortcut.combination?.title ?? L("录制快捷键")
        if !button.recording { button.title = button.idleTitle }
        button.receive = { shortcut.apply($0) }
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject var shortcut = GlobalShortcut.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("快速打开快捷键")).font(.headline)
            HStack {
                ShortcutRecorder(shortcut: shortcut).frame(height: 26)
                Button(L("清除")) { shortcut.clear() }.disabled(shortcut.combination == nil)
            }
            Text(L("在任何应用中打开或关闭 FuseBar。至少两个修饰键，包含 ⌘ 或 ⌃。"))
                .font(.caption).foregroundStyle(.secondary)
            if let error = shortcut.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }
}
