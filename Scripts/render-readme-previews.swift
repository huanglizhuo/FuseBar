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
        var pages: [(String, PopoverView.Page)] = [("status", .status), ("settings", .settings),
            ("guide", .guide), ("wifi", .wifi), ("sound", .sound), ("system", .system),
            ("coding", .status), ("projects", .projects), ("input-sources", .inputSources)]
        if L10n.language == "en" { pages += [("status-dark", .status), ("search", .status), ("search-empty", .status), ("recent", .status)] }
        for (name, page) in pages {
            let dark = name == "status-dark"
            defaults.set(name == "recent" ? ["action:sound", "action:settings", "action:files"] : [], forKey: "menuRecentActions")
            defaults.set(name == "coding", forKey: "codingLayout")
            let projects = CodingProjects(defaults: defaults)
            if projects.items.isEmpty { projects.save(CodingProject(name: "FuseBar", preview: "http://localhost:3000", repository: "https://github.com/huanglizhuo/FuseBar")) }
            let content = PopoverView(store: store, initialPage: page, preview: true, initialQuery: name == "search" ? "Wi-Fi" : name == "search-empty" ? "zz-no-match" : "", isSubmenu: [.wifi, .sound, .inputSources].contains(page), focusSearch: name == "recent",
                                      onQuickAction: { _ in }, onOpenApplication: { _ in }, shelf: shelf)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16).background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, dark ? .dark : .light)
            let hosting = NSHostingView(rootView: content)
            let size = hosting.fittingSize
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
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
        defaults.removeObject(forKey: "menuRecentActions")
        if L10n.language == "en" {
            defaults.set(false, forKey: "codingLayout")
            for (name, page) in [("battery", PopoverView.Page.battery), ("wifi", .wifi), ("sound", .sound), ("input-sources", .inputSources)] {
                // Composed offscreen layout preview, not evidence of live popover placement.
                let content = HStack(alignment: .top, spacing: 12) {
                    PopoverView(store: store, preview: true, onQuickAction: { _ in }, onOpenApplication: { _ in }, shelf: shelf)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    PopoverView(store: store, initialPage: page, preview: true, isSubmenu: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding(16).background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light)
                let hosting = NSHostingView(rootView: content)
                let size = hosting.fittingSize
                let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: .aqua)
                window.contentView = hosting
                hosting.setFrameSize(size)
                RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                hosting.layoutSubtreeIfNeeded()
                if let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("side-\(name)-en.png"))
                }
            }
        }
        store.stop()
    }
}
