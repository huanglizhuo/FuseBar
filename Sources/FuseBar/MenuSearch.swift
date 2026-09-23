import Foundation

struct MenuSearchEntry: Identifiable, Equatable {
    enum Destination: Equatable { case application(URL), file(UUID), action(String) }
    let id: String
    let title: String
    let category: String
    let symbol: String
    let destination: Destination
}

/// Only indexes already discovered apps, explicit file bookmarks, and local menu actions.
/// Results exist only while a query is typed; there is no recents surface.
enum MenuSearchModel {
    static func results(_ entries: [MenuSearchEntry], query: String) -> [MenuSearchEntry] {
        var seen = Set<String>()
        let unique = entries.filter { seen.insert($0.id).inserted }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(unique.filter { $0.title.localizedStandardContains(query) || $0.category.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }.prefix(50))
    }
}
