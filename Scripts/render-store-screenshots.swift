import AppKit
import SwiftUI

// Renders the production SwiftUI views with a live, local snapshot. No device
// identifiers are shown because this separate tool does not request permissions.
@main
struct StoreScreenshotRenderer {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let store = StatusStore()
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, page, title, detail) in [
            ("01-status", PopoverView.Page.status, "Essential status.\nOne icon.", "Battery, Wi-Fi and sound at a glance.\nClick for the details."),
            ("02-preferences", PopoverView.Page.settings, "Make room for\nwhat matters.", "Choose the status you want to see.\nKeep control of your menu bar."),
            ("03-guide", PopoverView.Page.guide, "A simpler\nmenu bar.", "One compact entry.\nFree, native and local.")
        ] {
            let content = HStack(spacing: 110) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("FuseBar").font(.system(size: 24, weight: .semibold)).foregroundStyle(Color(red: 0.05, green: 0.4, blue: 0.45))
                    Text(title).font(.system(size: 58, weight: .semibold)).tracking(-2)
                    Text(detail).font(.system(size: 23)).foregroundStyle(.secondary).lineSpacing(8)
                    Text("macOS 14+ · Current interface: 简体中文").font(.system(size: 15)).foregroundStyle(.secondary)
                }.frame(width: 560, alignment: .leading)
                PopoverView(store: store, initialPage: page, preview: true)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08)))
                    .shadow(color: .black.opacity(0.12), radius: 25, x: 0, y: 12)
            }
            .frame(width: 1440, height: 900)
            .background(Color(red: 0.94, green: 0.96, blue: 0.96))
            .environment(\.colorScheme, .light)
            let hosting = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: .borderless, backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = hosting
            hosting.setFrameSize(NSSize(width: 1440, height: 900))
            hosting.layoutSubtreeIfNeeded()
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { continue }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try data.write(to: output.appendingPathComponent("\(name).png"))
            }
        }
        store.stop()
    }
}
