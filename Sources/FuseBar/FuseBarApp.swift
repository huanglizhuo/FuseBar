import AppKit
import Combine
import SwiftUI

@main
struct FuseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem?
    private let popover: NSPopover
    private let sideSubmenu: SideSubmenu

    override init() {
        popover = NSPopover()
        sideSubmenu = .shared
        super.init()
    }

    init(popover: NSPopover, sideSubmenu: SideSubmenu? = nil) {
        self.sideSubmenu = sideSubmenu ?? .shared
        self.popover = popover
        super.init()
    }
    private var store: StatusStore?
    private let inputSources = InputSourceStore.shared
    private var inputSelection: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private var outsideClickMonitor: Any?
    private var localEventMonitor: Any?
    private var previousApplication: NSRunningApplication?
    private var deactivateObserver: NSObjectProtocol?

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
        GlobalShortcut.shared.onInvoke = { [weak self] in
            guard !SystemPanelPresentation.shared.isPresenting, NSApp.modalWindow == nil,
                  (NSApp.keyWindow?.firstResponder as? RecordingButton)?.recording != true else { return }
            self?.togglePanel(focusSearch: true)
        }
        GlobalShortcut.shared.start()
        let item = NSStatusBar.system.statusItem(withLength: 28)
        self.item = item
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        // Use one mouse-down action, rather than combining transient auto-dismiss with mouse-up toggle.
        item.button?.sendAction(on: .leftMouseDown)
        popover.behavior = .applicationDefined
        popover.delegate = self
        popover.animates = false
        ApplicationShelf.shared.start()
        inputSources.start()
        inputSources.$centerSource.sink { [weak self] source in
            guard let self, let store = self.store else { return }
            self.updateIcon(store.snapshot, store.preferences, inputSource: source)
        }.store(in: &subscriptions)
        store.$snapshot.combineLatest(store.$preferences)
            .sink { [weak self] snapshot, preferences in self?.updateIcon(snapshot, preferences, inputSource: self?.inputSources.centerSource) }
            .store(in: &subscriptions)
    }

    func applicationWillTerminate(_ notification: Notification) {
        sideSubmenu.close()
        removeDismissalMonitors()
        GlobalShortcut.shared.stop()
        ApplicationShelf.shared.stop()
        inputSources.stop()
        inputSelection?.cancel()
        store?.stop()
    }

    func popoverDidClose(_ notification: Notification) { sideSubmenu.close(); removeDismissalMonitors() }

    func installDismissalMonitors() {
        removeDismissalMonitors()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            // AppKit invokes event monitors on the main thread. No deferred stale close action.
            MainActor.assumeIsolated {
                guard let self, !self.mouseIsOverStatusButton else { return }
                self.closeAllMenus()
            }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            let consume = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.type == .keyDown {
                    guard !SystemPanelPresentation.shared.isPresenting else { return false }
                    if event.keyCode == 53, NSApp.modalWindow == nil,
                       (event.window?.firstResponder as? RecordingButton)?.recording != true {
                        self.dismissInnermostPanel()
                        return true
                    }
                    return false
                }
                // The status button owns its own toggle. Never dismiss it in this monitor first.
                if self.mouseIsOverStatusButton { return false }
                self.dismissForOutsideClick(window: event.window)
                return false
            }
            return consume ? nil : event
        }
        deactivateObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                                     object: NSApp, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemPanelPresentation.shared.isPresenting, NSApp.modalWindow == nil else { return }
                self?.closeAllMenus()
            }
        }
    }

    func dismissForOutsideClick(window: NSWindow?) {
        let rootWindow = popover.contentViewController?.view.window
        if let window, window === rootWindow || sideSubmenu.contains(window) { return }
        closeAllMenus()
    }

    func closeAllMenus() {
        sideSubmenu.close()
        popover.performClose(nil)
        removeDismissalMonitors()
    }

    private func restorePreviousApplication() {
        guard let target = previousApplication, !target.isTerminated,
              target.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        NSApp.yieldActivation(to: target)
        target.activate(options: [])
    }

    private var mouseIsOverStatusButton: Bool {
        guard let button = item?.button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(NSEvent.mouseLocation)
    }

    private func removeDismissalMonitors() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
        outsideClickMonitor = nil
        localEventMonitor = nil
        deactivateObserver = nil
    }

    private func updateIcon(_ snapshot: StatusSnapshot, _ preferences: IndicatorPreferences, inputSource: KeyboardSource? = nil) {
        let renderer = ImageRenderer(content: OrbView(snapshot: snapshot, preferences: preferences, ink: .black, emphasized: true, inputSource: inputSource)
            .frame(width: 22, height: 22).environment(\.colorScheme, .light))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        if let image = renderer.nsImage {
            image.isTemplate = true
            item?.button?.image = image
        }
        let summary = snapshot.accessibilitySummary(preferences) + (inputSource.map { " · " + $0.name } ?? "")
        item?.button?.toolTip = summary
        item?.button?.setAccessibilityLabel(summary)
        item?.button?.setAccessibilityHelp(L("点击查看状态详情和设置"))
    }

    private func resetPopoverContent(focusSearch: Bool) {
        guard let store else { return }
        // Each presentation owns fresh navigation/form state; system data and preferences persist.
        popover.contentViewController = NSHostingController(rootView: PopoverView(store: store, focusSearch: focusSearch, onSelectInputSource: { [weak self] id in
            self?.selectInputSource(id)
        }, onQuickAction: { [weak self] action in
            self?.performQuickAction(action)
        }, onOpenApplication: { [weak self] url in
            self?.openApplication(url, title: url.deletingPathExtension().lastPathComponent)
        }))
    }

    private func selectInputSource(_ id: String) {
        inputSelection?.cancel()
        closeAllMenus()
        inputSelection = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await InputSourceSelection.perform(restoreFocus: {
                self.restorePreviousApplication()
            }, select: {
                self.inputSources.select(id)
            })
            if result == false {
                self.store?.errorMessage = self.inputSources.error
                self.togglePanel(focusSearch: false)
            }
        }
    }

    @objc private func togglePopover() { togglePanel(focusSearch: false) }

    private func togglePanel(focusSearch: Bool) {
        if popover.isShown || sideSubmenu.isShown { dismissAndRestoreFocus(); return }
        guard !SystemPanelPresentation.shared.isPresenting, NSApp.modalWindow == nil, let button = item?.button else { return }
        do {
            if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApplication = frontmost
            }
            inputSources.refresh()
            ApplicationShelf.shared.refresh()
            resetPopoverContent(focusSearch: focusSearch)
            store?.refresh()
            store?.refreshLoginStatus()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            if popover.isShown { installDismissalMonitors() }
        }
    }

    func dismissInnermostPanel() {
        if sideSubmenu.isShown { sideSubmenu.close(restoreParent: true) }
        else { dismissAndRestoreFocus() }
    }

    private func dismissAndRestoreFocus() {
        let restore = NSApp.isActive
        closeAllMenus()
        if restore { restorePreviousApplication() }
    }

    private func performQuickAction(_ action: QuickAction) {
        guard let url = action.applicationURL else {
            store?.errorMessage = L("当前系统找不到%@。", action.title)
            return
        }
        openApplication(url, title: action.title)
    }

    private func openApplication(_ url: URL, title: String) {
        closeAllMenus()
        Task { @MainActor [weak self] in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            } catch {
                guard let self else { return }
                self.store?.errorMessage = L("无法打开%@：%@", title, error.localizedDescription)
                if !self.popover.isShown { self.togglePopover() }
            }
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
