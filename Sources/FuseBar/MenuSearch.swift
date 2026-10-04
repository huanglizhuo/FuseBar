import Foundation

struct MenuSearchEntry: Identifiable, Equatable {
    enum Destination: Equatable {
        case application(URL), file(UUID), action(String)
        case audioOutput(String), bluetoothDevice(String), inputSource(String), project(UUID), settings(SettingsDestination)
    }
    let id: String
    let title: String
    let category: String
    let symbol: String
    let destination: Destination
    /// Extra names that find this entry, such as an app's on-disk or bundle name.
    var aliases: [String] = []
}

/// Only indexes already discovered apps, explicit file bookmarks, and local menu actions.
/// Results exist only while a query is typed; there is no recents surface.
enum MenuSearchModel {
    /// Best match first: exact, prefix, word prefix, then substring of the title or an
    /// alias; the category is a last resort for 3+ characters. Ties keep entry order,
    /// which lists running apps by recent use first.
    static func results(_ entries: [MenuSearchEntry], query: String) -> [MenuSearchEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var seen = Set<String>()
        let ranked = entries.enumerated().compactMap { index, entry -> (rank: Int, index: Int, entry: MenuSearchEntry)? in
            guard seen.insert(entry.id).inserted, let rank = rank(entry, query: query) else { return nil }
            return (rank, index, entry)
        }
        return ranked.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }.prefix(50).map(\.entry)
    }

    private static func rank(_ entry: MenuSearchEntry, query: String) -> Int? {
        let names = searchNames(entry)
        // Every better tier implies a substring match, so most entries stop at this cheap check.
        guard names.contains(where: { $0.localizedStandardContains(query) }) else {
            return query.count >= 3 && entry.category.localizedStandardContains(query) ? 4 : nil
        }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        func hasPrefix(_ text: Substring) -> Bool { text.range(of: query, options: options.union(.anchored)) != nil }
        if names.contains(where: { $0.compare(query, options: options) == .orderedSame }) { return 0 }
        if names.contains(where: { hasPrefix($0[...]) }) { return 1 }
        if names.contains(where: { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: hasPrefix) }) { return 2 }
        return 3
    }

    /// Title and aliases, the initials of multi-word names ("vsc"), and pinyin for Chinese titles.
    private static func searchNames(_ entry: MenuSearchEntry) -> [String] {
        let names = ([entry.title] + entry.aliases).filter { !$0.isEmpty }
        let initials = names.compactMap { name -> String? in
            guard name.contains(where: { !$0.isLetter && !$0.isNumber }) else { return nil }
            let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return words.count > 1 ? String(words.compactMap(\.first)) : nil
        }
        return names + initials + pinyin(entry.title)
    }

    private static let pinyinCache = NSCache<NSString, NSArray>()

    /// Full pinyin and initials (微信 → weixin, wx) from the system transliterator; cached per name.
    static func pinyin(_ name: String) -> [String] {
        guard name.unicodeScalars.contains(where: \.properties.isIdeographic) else { return [] }
        if let cached = pinyinCache.object(forKey: name as NSString) as? [String] { return cached }
        let latin = NSMutableString(string: name)
        CFStringTransform(latin, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(latin, nil, kCFStringTransformStripDiacritics, false)
        let syllables = (latin as String).split(separator: " ")
        let result = [syllables.joined(), String(syllables.compactMap(\.first))]
        pinyinCache.setObject(result as NSArray, forKey: name as NSString)
        return result
    }
}
