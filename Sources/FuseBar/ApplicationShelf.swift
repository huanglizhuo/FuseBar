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

    static func home(running: [ShelfApplication], recentIDs: [String] = []) -> [ShelfApplication] {
        recent(visible(running.filter(\.running), query: ""), ids: recentIDs)
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
    @Published private(set) var frontmostID: String?
    @Published private(set) var recentIDs: [String]
    private var scanned = false
    @Published private(set) var running: [ShelfApplication] = []
    private let defaults: UserDefaults
    private var observers: [NSObjectProtocol] = []
    private let worker = DispatchQueue(label: "com.fusebar.application-metadata", qos: .utility)
    private let readApplications: @Sendable () -> [ShelfApplication]
    private var refreshing = false
    private var refreshPending = false
    private var revision = 0

    init(defaults: UserDefaults = .standard,
         readApplications: @escaping @Sendable () -> [ShelfApplication] = { ApplicationShelf.readApplications() }) {
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
                    self.refresh()
                }
            })
        }
        if let app = NSWorkspace.shared.frontmostApplication, app.activationPolicy == .regular,
           let id = app.bundleIdentifier { recordRecentApplication(id) }
        refresh()
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
            let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            Task { @MainActor in
                guard let self else { return }
                self.refreshing = false
                if self.revision == token {
                    self.running = ApplicationShelfModel.recent(apps.filter(\.running), ids: self.recentIDs)
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

    func discoverApplications() {
        guard !scanned, !scanning else { return }
        scanning = true
        let userApplications = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
            let result = ApplicationShelfModel.visible(found.sorted { nameIsBefore($0.name, $1.name) }, query: "")
            Task { @MainActor in self?.installed = result; self?.scanning = false; self?.scanned = true }
        }
    }

    var searchable: [ShelfApplication] {
        ApplicationShelfModel.visible(running + installed, query: "")
    }

    func forceTerminate(_ app: ShelfApplication) -> String? {
        let targets = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).filter { !$0.isTerminated }
        guard !targets.isEmpty else { refresh(); return L("应用已经退出，请刷新后重试。") }
        let succeeded = targets.allSatisfy { $0.forceTerminate() }
        refresh()
        return succeeded ? nil : L("系统未接受强制退出，请重试。")
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
