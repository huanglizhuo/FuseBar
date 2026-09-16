import AppKit
import SwiftUI

// Offscreen native views with explicit sample status and the local running-app shelf.
// No hardware controls are invoked. This is not a live menu-bar capture.
@main
struct ReadmePreviews {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let suite = "FuseBar.ReadmePreview"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StatusStore(defaults: defaults, demo: true)
        let shelf = ApplicationShelf(defaults: defaults)
        shelf.refresh()
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, page) in [("status", PopoverView.Page.status), ("settings", .settings),
                             ("guide", .guide), ("wifi", .wifi), ("sound", .sound), ("system", .system)] {
            let content = PopoverView(store: store, initialPage: page, preview: true,
                                      onQuickAction: { _ in }, onOpenApplication: { _ in }, shelf: shelf)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16).background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, .light)
            let hosting = NSHostingView(rootView: content)
            let size = hosting.fittingSize
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = hosting
            hosting.setFrameSize(size)
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds),
                  let _ = bitmap.representation(using: .png, properties: [:]) else { continue }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name)-\(L10n.language).png"))
            print("\(L10n.language) \(name): \(size)")
        }
        store.stop()
    }
}
