import AppKit
import Carbon
import Combine
import SwiftUI

struct KeyboardSource: Identifiable {
    let id: String
    let name: String
    let language: String
    let icon: NSImage?
    var templateIcon: NSImage? = nil

    var fallback: String {
        switch language.split(separator: "-").first {
        case "zh": return "中"
        case "ja": return "あ"
        case "ko": return "한"
        default: return String(language.prefix(2)).uppercased().isEmpty ? "A" : String(language.prefix(2)).uppercased()
        }
    }
}

@MainActor protocol InputSourceClient {
    func read() -> (sources: [KeyboardSource], currentID: String?)
    func select(_ id: String) -> OSStatus
}

@MainActor struct SystemInputSourceClient: InputSourceClient {
    private func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    private func enabledSources() -> [TISInputSource] {
        guard let list = TISCreateInputSourceList(nil, false) else { return [] }
        let all = list.takeRetainedValue() as! [TISInputSource]
        return all.filter {
            property($0, kTISPropertyInputSourceCategory) as? String == kTISCategoryKeyboardInputSource as String &&
            property($0, kTISPropertyInputSourceIsEnabled) as? Bool == true &&
            property($0, kTISPropertyInputSourceIsSelectCapable) as? Bool == true
        }
    }

    func read() -> (sources: [KeyboardSource], currentID: String?) {
        let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        var seen = Set<String>()
        let sources = enabledSources().compactMap { source -> KeyboardSource? in
            guard let id = property(source, kTISPropertyInputSourceID) as? String, seen.insert(id).inserted else { return nil }
            var icon: NSImage?
            if let url = property(source, kTISPropertyIconImageURL) as? URL { icon = NSImage(contentsOf: url) }
            if icon == nil, let ref = TISGetInputSourceProperty(source, kTISPropertyIconRef) {
                // ABC and some keyboard layouts expose only this legacy, public representation.
                icon = NSImage(iconRef: OpaquePointer(ref))
            }
            icon?.size = NSSize(width: 16, height: 16)
            return KeyboardSource(id: id, name: property(source, kTISPropertyLocalizedName) as? String ?? id,
                                  language: (property(source, kTISPropertyInputSourceLanguages) as? [String])?.first ?? "",
                                  icon: icon, templateIcon: icon.flatMap(Self.template))
        }
        return (sources, current.flatMap { property($0, kTISPropertyInputSourceID) as? String })
    }

    /// Preserve white cutouts in vendor artwork when the whole status item becomes a template.
    static func template(_ image: NSImage) -> NSImage? {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: 32, height: 32))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var totalAlpha = 0.0
        var totalInk = 0.0
        for offset in stride(from: 0, to: 4096, by: 4) {
            let alpha = Double(pixels[offset + 3])
            let luminance = 0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) + 0.0722 * Double(pixels[offset + 2])
            totalAlpha += alpha
            totalInk += max(0, alpha - luminance)
        }
        let whiteArtwork = totalInk < totalAlpha * 0.05
        for offset in stride(from: 0, to: 4096, by: 4) {
            let alpha = Double(pixels[offset + 3])
            let luminance = 0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) + 0.0722 * Double(pixels[offset + 2])
            pixels[offset + 3] = UInt8(max(0, min(255, whiteArtwork ? alpha : alpha - luminance)))
            pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0
        }
        guard let cgImage = context.makeImage() else { return nil }
        let result = NSImage(cgImage: cgImage, size: NSSize(width: 14, height: 14))
        result.isTemplate = true
        return result
    }

    func select(_ id: String) -> OSStatus {
        guard let source = enabledSources().first(where: { property($0, kTISPropertyInputSourceID) as? String == id }) else { return OSStatus(paramErr) }
        return TISSelectInputSource(source)
    }
}

struct InputSourcePresentation {
    private(set) var currentID: String?
    private(set) var visibleUntil: Date?
    mutating func update(_ id: String?, now: Date) {
        if let previous = currentID, let id, previous != id { visibleUntil = now.addingTimeInterval(2) }
        if id == nil { visibleUntil = nil }
        currentID = id
    }
    func visible(always: Bool, now: Date) -> Bool {
        currentID != nil && (always || visibleUntil.map { now < $0 } == true)
    }
}

@MainActor final class InputSourceStore: ObservableObject {
    static let shared = InputSourceStore()
    @Published private(set) var sources: [KeyboardSource] = []
    @Published private(set) var currentID: String?
    @Published private(set) var centerSource: KeyboardSource?
    @Published var error: String?
    @Published var alwaysShow: Bool {
        didSet { defaults.set(alwaysShow, forKey: "alwaysShowInputSource"); updateCenter() }
    }
    private let defaults: UserDefaults
    private let client: InputSourceClient
    private var presentation = InputSourcePresentation()
    private var observers: [NSObjectProtocol] = []
    private var expiration: Task<Void, Never>?
    var current: KeyboardSource? { sources.first { $0.id == currentID } }

    init(defaults: UserDefaults = .standard, client: InputSourceClient? = nil) {
        self.defaults = defaults
        self.client = client ?? SystemInputSourceClient()
        alwaysShow = defaults.bool(forKey: "alwaysShowInputSource")
    }

    func start() {
        guard observers.isEmpty else { return }
        refresh()
        for name in [kTISNotifySelectedKeyboardInputSourceChanged, kTISNotifyEnabledKeyboardInputSourcesChanged] {
            observers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name! as String), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
    }

    func stop() {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.removeAll()
        expiration?.cancel(); expiration = nil
    }

    func refresh() {
        let result = client.read()
        sources = result.sources
        currentID = result.currentID
        presentation.update(currentID, now: Date())
        updateCenter()
        expiration?.cancel()
        if let until = presentation.visibleUntil, until > Date() {
            let delay = until.timeIntervalSinceNow
            expiration = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.updateCenter()
            }
        }
    }

    private func updateCenter() {
        centerSource = presentation.visible(always: alwaysShow, now: Date()) ? current : nil
    }

    @discardableResult func select(_ id: String) -> Bool {
        let status = client.select(id)
        refresh()
        guard status == noErr, currentID == id else {
            error = L("无法切换输入源，请重试或使用系统输入菜单。")
            return false
        }
        error = nil
        return true
    }
}

struct InputSourceGlyph: View {
    let source: KeyboardSource
    var body: some View {
        if let icon = source.templateIcon?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            Image(decorative: icon, scale: 1).renderingMode(.template)
                .resizable().scaledToFit().frame(width: 14, height: 14).foregroundStyle(.primary)
        } else {
            Text(source.fallback).font(.system(size: 12, weight: .semibold)).minimumScaleFactor(0.5)
        }
    }
}
