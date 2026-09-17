import AppKit
import Combine
import UniformTypeIdentifiers

struct ShelfApplication: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL?
    let running: Bool
}

/// Stable fallback ordering with the most recently activated or launched app first.
enum ApplicationShelfModel {
    static func normalizedPins(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func compact(_ apps: [ShelfApplication], capacity: Int = 12) -> (apps: [ShelfApplication], overflow: Bool) {
        let running = visible(apps.filter(\.running), query: "")
        guard capacity > 0 else { return ([], !running.isEmpty) }
        let overflow = running.count > capacity
        return (Array(running.prefix(overflow ? capacity - 1 : capacity)), overflow)
    }

    static func home(favorites: [ShelfApplication], running: [ShelfApplication], includeFavorites: Bool, recentIDs: [String] = []) -> [ShelfApplication] {
        recent(visible((includeFavorites ? favorites : []) + running.filter(\.running), query: ""), ids: recentIDs)
    }

    static func recent(_ apps: [ShelfApplication], ids: [String]) -> [ShelfApplication] {
        let apps = visible(apps, query: "")
        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        let order = normalizedPins(ids)
        let recorded = Set(order)
        return order.compactMap { byID[$0] } + apps.filter { !recorded.contains($0.id) }
    }

    static func stable(previous: [ShelfApplication], current: [ShelfApplication]) -> [ShelfApplication] {
        let current = visible(current, query: "")
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let previousIDs = Set(previous.map(\.id))
        return previous.compactMap { byID[$0.id] } + current.filter { !previousIDs.contains($0.id) }
    }

    static func moving(_ ids: [String], id: String, offset: Int) -> [String] {
        var result = normalizedPins(ids)
        guard let index = result.firstIndex(of: id), result.indices.contains(index + offset) else { return result }
        result.swapAt(index, index + offset)
        return result
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
    @Published private(set) var scanning = false
    @Published private(set) var frontmostID: String?
    @Published private(set) var recentIDs: [String]
    private var scanned = false
    @Published private(set) var running: [ShelfApplication] = []
    @Published private(set) var favorites: [ShelfApplication] = []
    private let defaults: UserDefaults
    private var pins: [String]
    private var bookmarks: [String: Data]
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recentIDs = Array(ApplicationShelfModel.normalizedPins(defaults.stringArray(forKey: "recentApplications") ?? []).prefix(100))
        bookmarks = defaults.dictionary(forKey: "applicationBookmarks") as? [String: Data] ?? [:]
        pins = ApplicationShelfModel.normalizedPins(defaults.stringArray(forKey: "pinnedApplications") ?? [])
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
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    func refresh() {
        let current = ApplicationShelfModel.visible(NSWorkspace.shared.runningApplications.sorted {
            ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast)
        }.compactMap { app in
            guard app.activationPolicy == .regular, !app.isTerminated,
                  let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
            return ShelfApplication(id: id, name: app.localizedName ?? id, url: app.bundleURL, running: true)
        }, query: "")
        running = ApplicationShelfModel.recent(current, ids: recentIDs)
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            frontmostID = frontmost.bundleIdentifier
        }
        favorites = pins.map { id in
            if let app = running.first(where: { $0.id == id }) { return app }
            let url = self.applicationURL(id)
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? id
            return ShelfApplication(id: id, name: name, url: url, running: false)
        }
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
            let result = ApplicationShelfModel.visible(found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, query: "")
            Task { @MainActor in self?.installed = result; self?.scanning = false; self?.scanned = true }
        }
    }

    func addApplication() -> String? {
        let panel = NSOpenPanel()
        panel.title = L("添加应用")
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard SystemPanelPresentation.shared.run(panel) == .OK else { return nil }
        var invalid = false
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { invalid = true; continue }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let bookmark = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil) else { invalid = true; continue }
            bookmarks[id] = bookmark
            if !pins.contains(id) { pins.append(id) }
        }
        defaults.set(pins, forKey: "pinnedApplications")
        refresh()
        defaults.set(bookmarks, forKey: "applicationBookmarks")
        return invalid ? L("部分项目不是可用的应用。") : nil
    }

    private func applicationURL(_ id: String) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url }
        guard let data = bookmarks[id] else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale), !stale else { return nil }
        return url
    }

    var searchable: [ShelfApplication] {
        ApplicationShelfModel.visible(favorites + running + installed, query: "")
    }

    func isPinned(_ app: ShelfApplication) -> Bool { pins.contains(app.id) }

    func move(_ app: ShelfApplication, offset: Int) {
        pins = ApplicationShelfModel.moving(pins, id: app.id, offset: offset)
        defaults.set(pins, forKey: "pinnedApplications")
        refresh()
    }

    func canMove(_ app: ShelfApplication, offset: Int) -> Bool {
        guard let index = pins.firstIndex(of: app.id) else { return false }
        return pins.indices.contains(index + offset)
    }

    func setHidden(_ hidden: Bool, app: ShelfApplication) -> String? {
        let targets = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).filter { !$0.isTerminated }
        guard !targets.isEmpty else { refresh(); return L("应用已经退出，请刷新后重试。") }
        let succeeded = targets.map { hidden ? $0.hide() : $0.unhide() }.allSatisfy { $0 }
        refresh()
        return succeeded ? nil : L("系统未接受显示状态请求，请切换到该应用操作。")
    }

    func togglePin(_ app: ShelfApplication) {
        if pins.contains(app.id) { pins.removeAll { $0 == app.id }; bookmarks.removeValue(forKey: app.id); defaults.set(bookmarks, forKey: "applicationBookmarks") }
        else { pins.append(app.id) }
        defaults.set(pins, forKey: "pinnedApplications")
        refresh()
    }
}
