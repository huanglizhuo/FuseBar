import AppKit
import Combine

struct ShelfApplication: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL?
    let running: Bool
}

/// Pure ordering rules keep favorites stable while processes launch and quit.
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
    @Published private(set) var running: [ShelfApplication] = []
    @Published private(set) var favorites: [ShelfApplication] = []
    private let defaults: UserDefaults
    private var pins: [String]
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pins = ApplicationShelfModel.normalizedPins(defaults.stringArray(forKey: "pinnedApplications") ?? [])
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
    }

    func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    func refresh() {
        running = ApplicationShelfModel.visible(NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, !app.isTerminated,
                  let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
            return ShelfApplication(id: id, name: app.localizedName ?? id, url: app.bundleURL, running: true)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, query: "")
        favorites = pins.map { id in
            if let app = running.first(where: { $0.id == id }) { return app }
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? id
            return ShelfApplication(id: id, name: name, url: url, running: false)
        }
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
        if pins.contains(app.id) { pins.removeAll { $0 == app.id } }
        else { pins.append(app.id) }
        defaults.set(pins, forKey: "pinnedApplications")
        refresh()
    }
}
