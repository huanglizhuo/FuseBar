import AppKit
import Combine
import SwiftUI

@main
struct FuseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var store: StatusStore?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        if let index = CommandLine.arguments.firstIndex(of: "--render-gallery"), CommandLine.arguments.count > index + 1 {
            renderGallery(to: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        let store = StatusStore()
        self.store = store
        let item = NSStatusBar.system.statusItem(withLength: 28)
        self.item = item
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: PopoverView(store: store))
        store.$snapshot.combineLatest(store.$preferences)
            .sink { [weak self] snapshot, preferences in self?.updateIcon(snapshot, preferences) }
            .store(in: &subscriptions)
    }

    func applicationWillTerminate(_ notification: Notification) { store?.stop() }

    private func updateIcon(_ snapshot: StatusSnapshot, _ preferences: IndicatorPreferences) {
        let renderer = ImageRenderer(content: OrbView(snapshot: snapshot, preferences: preferences)
            .frame(width: 22, height: 22).environment(\.colorScheme, .light))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        if let image = renderer.nsImage {
            image.isTemplate = true
            item?.button?.image = image
        }
        let summary = snapshot.accessibilitySummary(preferences)
        item?.button?.toolTip = summary
        item?.button?.setAccessibilityLabel(summary)
        item?.button?.setAccessibilityHelp("点击查看状态详情和设置")
    }

    @objc private func togglePopover() {
        guard let button = item?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            store?.refresh()
            store?.refreshLoginStatus()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func renderGallery(to directory: String) {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let renderer = ImageRenderer(content: OrbGallery().environment(\.colorScheme, scheme))
                renderer.scale = 2
                guard let image = renderer.cgImage else { continue }
                let bitmap = NSBitmapImageRep(cgImage: image)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: url.appendingPathComponent("orb-gallery-\(name).png"))
                }
            }
            let demoDefaults = UserDefaults(suiteName: "com.mergebar.preview")!
            let demoStore = StatusStore(defaults: demoDefaults, demo: true)
            // ImageRenderer cannot draw AppKit-backed sliders and checkboxes. Render those
            // through an offscreen hosting view instead of exporting placeholder symbols.
            let hosting = NSHostingView(rootView: InterfaceGallery(store: demoStore).environment(\.colorScheme, .light))
            let size = hosting.fittingSize
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = hosting
            hosting.setFrameSize(size)
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
            if let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: url.appendingPathComponent("interface-preview.png"))
                }
            }
        } catch { NSLog("Gallery render failed: %@", error.localizedDescription) }
    }
}
