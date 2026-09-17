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
        let inputSources = SystemInputSourceClient().read().sources
        for scheme in [ColorScheme.light, .dark] {
            let inputGallery = HStack(spacing: 24) {
                ForEach(inputSources) { source in
                    VStack(spacing: 8) {
                        OrbView(snapshot: .normal, emphasized: true, inputSource: source)
                            .frame(width: 44, height: 44)
                        InputSourceGlyph(source: source).frame(width: 20, height: 20)
                        Text(source.name).font(.caption).foregroundStyle(.primary)
                    }
                }
            }.padding(20).background(scheme == .dark ? Color.black : Color.white)
                .environment(\.colorScheme, scheme)
            let inputRenderer = ImageRenderer(content: inputGallery)
            inputRenderer.scale = 3
            if let cgImage = inputRenderer.cgImage,
               let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) {
                let file = scheme == .dark ? "input-source-icons-dark.png" : "input-source-icons.png"
                try data.write(to: output.appendingPathComponent(file))
            }
        }
        for (name, page) in [("status", PopoverView.Page.status), ("settings", .settings),
                             ("guide", .guide), ("wifi", .wifi), ("sound", .sound), ("system", .system), ("coding", .status), ("projects", .projects), ("input-sources", .inputSources)] {
            defaults.set(name == "coding", forKey: "codingLayout")
            let projects = CodingProjects(defaults: defaults)
            if projects.items.isEmpty { projects.save(CodingProject(name: "FuseBar", preview: "http://localhost:3000", repository: "https://github.com/huanglizhuo/FuseBar")) }
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
