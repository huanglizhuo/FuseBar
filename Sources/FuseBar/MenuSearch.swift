import Foundation
import Combine

struct MenuSearchEntry: Identifiable, Equatable {
    enum Destination: Equatable { case application(URL), file(UUID), action(String) }
    let id: String
    let title: String
    let category: String
    let symbol: String
    let destination: Destination
}

/// Only indexes already discovered apps, explicit file bookmarks, and local menu actions.
enum MenuSearchModel {
    static func results(_ entries: [MenuSearchEntry], query: String, recentIDs: [String]) -> [MenuSearchEntry] {
        var seen = Set<String>()
        let unique = entries.filter { seen.insert($0.id).inserted }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            let byID = Dictionary(uniqueKeysWithValues: unique.map { ($0.id, $0) })
            var recentSeen = Set<String>()
            return recentIDs.filter { recentSeen.insert($0).inserted }.compactMap { byID[$0] }.prefix(3).map { $0 }
        }
        return Array(unique.filter { $0.title.localizedStandardContains(query) || $0.category.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }.prefix(50))
    }
}

@MainActor final class MenuSearchHistory: ObservableObject {
    @Published private(set) var ids: [String]
    private let defaults: UserDefaults
    init(defaults: UserDefaults) {
        self.defaults = defaults
        ids = defaults.stringArray(forKey: "menuRecentActions") ?? []
    }
    func record(_ id: String) {
        ids = Array(([id] + ids.filter { $0 != id }).prefix(20))
        defaults.set(ids, forKey: "menuRecentActions")
    }
}
