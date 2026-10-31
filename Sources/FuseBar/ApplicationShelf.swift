import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ShelfApplication: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let url: URL?
    let running: Bool
}

/// Stable fallback ordering with the most recently activated or launched app first.
enum ApplicationShelfModel {
    static func normalizedOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Running apps by recent use. The app the panel was opened from takes the last visible
    /// slot: still reachable (e.g. to force quit it) without holding the most useful first one.
    static func home(running: [ShelfApplication], recentIDs: [String] = [], frontmostID: String? = nil, limit: Int = 12) -> [ShelfApplication] {
        let apps = recent(visible(running.filter(\.running), query: ""), ids: recentIDs)
        guard let current = apps.first(where: { $0.id == frontmostID }) else { return Array(apps.prefix(limit)) }
        return Array(apps.filter { $0.id != current.id }.prefix(limit - 1)) + [current]
    }

    static func recent(_ apps: [ShelfApplication], ids: [String]) -> [ShelfApplication] {
        let apps = visible(apps, query: "")
        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        let order = normalizedOrder(ids)
        let recorded = Set(order)
        return order.compactMap { byID[$0] } + apps.filter { !recorded.contains($0.id) }
    }

    static func stable(previous: [ShelfApplication], current: [ShelfApplication]) -> [ShelfApplication] {
        let current = visible(current, query: "")
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let previousIDs = Set(previous.map(\.id))
        return previous.compactMap { byID[$0.id] } + current.filter { !previousIDs.contains($0.id) }
    }

    static func visible(_ apps: [ShelfApplication], query: String) -> [ShelfApplication] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        return apps.filter { seen.insert($0.id).inserted &&
            (query.isEmpty || $0.name.localizedStandardContains(query) || $0.id.localizedStandardContains(query)) }
    }
}

@MainActor
final class ApplicationShelf: ObservableObject {
    static let shared = ApplicationShelf()
    @Published private(set) var installed: [ShelfApplication] = []
    private var scanning = false
    private var scanPending = false
    @Published private(set) var frontmostID: String?
    @Published private(set) var recentIDs: [String]
    private var lastScan: Date?
    private let readInstalledApplications: @Sendable () -> [ShelfApplication]
    private let now: () -> Date
    @Published private(set) var running: [ShelfApplication] = []
    private let defaults: UserDefaults
    private var observers: [NSObjectProtocol] = []
    private let worker = DispatchQueue(label: "com.fusebar.application-metadata", qos: .utility)
    private let readApplications: @Sendable () -> [ShelfApplication]
    private var refreshing = false
    private var refreshPending = false
    private var revision = 0

    init(defaults: UserDefaults = .standard,
         readApplications: @escaping @Sendable () -> [ShelfApplication] = { ApplicationShelf.readApplications() },
         readInstalledApplications: @escaping @Sendable () -> [ShelfApplication] = { ApplicationShelf.readInstalledApplications() },
         now: @escaping () -> Date = Date.init) {
        self.readInstalledApplications = readInstalledApplications
        self.now = now
        self.readApplications = readApplications
        self.defaults = defaults
        recentIDs = Array(ApplicationShelfModel.normalizedOrder(defaults.stringArray(forKey: "recentApplications") ?? []).prefix(100))
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name == NSWorkspace.didActivateApplicationNotification || name == NSWorkspace.didLaunchApplicationNotification,
                       let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                       app.activationPolicy == .regular, let id = app.bundleIdentifier {
                        self.recordRecentApplication(id)
                    }
                    if name == NSWorkspace.didActivateApplicationNotification {
                        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                           app.activationPolicy == .regular, app.bundleIdentifier != Bundle.main.bundleIdentifier {
                            if let id = app.bundleIdentifier { self.recordActivation(id) }
                        }
                    } else { self.refresh() }
                }
            })
        }
        if let app = NSWorkspace.shared.frontmostApplication, app.activationPolicy == .regular,
           let id = app.bundleIdentifier { recordRecentApplication(id) }
        refresh()
    }

    func recordActivation(_ id: String) {
        guard !id.isEmpty, id != Bundle.main.bundleIdentifier else { return }
        frontmostID = id
        recordRecentApplication(id)
    }

    func recordRecentApplication(_ id: String) {
        guard !id.isEmpty, id != Bundle.main.bundleIdentifier, id != recentIDs.first else { return }
        recentIDs = Array(([id] + recentIDs.filter { $0 != id }).prefix(100))
        defaults.set(recentIDs, forKey: "recentApplications")
    }

    func stop() {
        revision += 1
        refreshPending = false
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    func refresh() {
        revision += 1
        guard !refreshing else { refreshPending = true; return }
        refreshing = true
        let token = revision
        worker.async { [weak self, readApplications] in
            let apps = readApplications()
            Task { @MainActor in
                guard let self else { return }
                self.refreshing = false
                if self.revision == token {
                    self.running = ApplicationShelfModel.recent(apps.filter(\.running), ids: self.recentIDs)
                    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    if frontmost != Bundle.main.bundleIdentifier { self.frontmostID = frontmost }
                    ApplicationIconCache.prewarm(self.running.compactMap(\.url))
                }
                if self.refreshPending { self.refreshPending = false; self.refresh() }
            }
        }
    }

    nonisolated private static func readApplications() -> [ShelfApplication] {
        ApplicationShelfModel.visible(NSWorkspace.shared.runningApplications.sorted {
            ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast)
        }.compactMap { app in
            guard app.activationPolicy == .regular, !app.isTerminated,
                  let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
            return ShelfApplication(id: id, name: app.localizedName ?? id, url: app.bundleURL, running: true)
        }, query: "")
    }

    /// Refresh only on demand, at most once per minute; no filesystem polling.
    func discoverApplications() {
        guard !scanning, lastScan.map({ now().timeIntervalSince($0) >= 60 }) ?? true else { return }
        scanning = true
        worker.async { [weak self, readInstalledApplications] in
            let result = readInstalledApplications()
            Task { @MainActor in
                guard let self else { return }
                self.installed = result
                self.scanning = false
                self.lastScan = self.now()
                if self.scanPending {
                    self.scanPending = false
                    self.invalidateInstalledApplications()
                }
            }
        }
    }

    func invalidateInstalledApplications() {
        lastScan = nil
        if scanning { scanPending = true } else { discoverApplications() }
    }

    nonisolated private static func readInstalledApplications() -> [ShelfApplication] {
        let userApplications = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        var found: [ShelfApplication] = []
        for root in [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"), userApplications] {
            guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in entries {
                if url.pathExtension == "app" {
                    entries.skipDescendants()
                    guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
                    found.append(ShelfApplication(id: id, name: FileManager.default.displayName(atPath: url.path), url: url, running: false))
                } else if url.pathComponents.count - root.pathComponents.count >= 2 { entries.skipDescendants() }
            }
        }
        return ApplicationShelfModel.visible(found.sorted { nameIsBefore($0.name, $1.name) }, query: "")
    }

    var searchable: [ShelfApplication] {
        ApplicationShelfModel.visible(ApplicationShelfModel.recent(running, ids: recentIDs) + installed, query: "")
    }

    func terminate(_ app: ShelfApplication, force: Bool = false) -> String? {
        let targets = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).filter { !$0.isTerminated }
        guard !targets.isEmpty else { refresh(); return L("应用已经退出，请刷新后重试。") }
        let succeeded = targets.map { force ? $0.forceTerminate() : $0.terminate() }.allSatisfy { $0 }
        refresh()
        return succeeded ? nil : force ? L("系统未接受强制退出，请重试。") : L("系统未接受退出请求，请切换到该应用操作。")
    }

    func setHidden(_ hidden: Bool, app: ShelfApplication) -> String? {
        let targets = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).filter { !$0.isTerminated }
        guard !targets.isEmpty else { refresh(); return L("应用已经退出，请刷新后重试。") }
        let succeeded = targets.map { hidden ? $0.hide() : $0.unhide() }.allSatisfy { $0 }
        refresh()
        return succeeded ? nil : L("系统未接受显示状态请求，请切换到该应用操作。")
    }
}

/// View rendering only reads cached images; filesystem icon lookup never runs in body.
private enum ApplicationIconCache {
    static let images: NSCache<NSURL, NSImage> = { let cache = NSCache<NSURL, NSImage>(); cache.countLimit = 256; return cache }()
    static let worker = DispatchQueue(label: "com.fusebar.application-icons", qos: .utility)
    static func cached(_ url: URL) -> NSImage? { images.object(forKey: url as NSURL) }
    static func prewarm(_ urls: [URL]) {
        worker.async {
            for url in urls where images.object(forKey: url as NSURL) == nil {
                images.setObject(NSWorkspace.shared.icon(forFile: url.path), forKey: url as NSURL)
            }
        }
    }
    static func load(_ url: URL) async -> NSImage {
        await withCheckedContinuation { continuation in
            worker.async {
                if let image = images.object(forKey: url as NSURL) { continuation.resume(returning: image); return }
                let image = NSWorkspace.shared.icon(forFile: url.path)
                images.setObject(image, forKey: url as NSURL)
                continuation.resume(returning: image)
            }
        }
    }
}

struct ApplicationIcon: View {
    let url: URL
    @State private var icon: NSImage?
    init(url: URL) {
        self.url = url
        _icon = State(initialValue: ApplicationIconCache.cached(url))
    }
    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable() }
            else { Image(systemName: "app.dashed").resizable() }
        }.task(id: url) {
            guard icon == nil else { return }
            let image = await ApplicationIconCache.load(url)
            if !Task.isCancelled { icon = image }
        }
    }
}
