import XCTest
@testable import FuseBar

final class MenuSearchTests: XCTestCase {
    private let entries = [
        MenuSearchEntry(id: "app:editor", title: "Éditeur", category: "Application", symbol: "app", destination: .application(URL(fileURLWithPath: "/Applications/Editor.app"))),
        MenuSearchEntry(id: "file:work", title: "工作目录", category: "Files", symbol: "folder", destination: .file(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)),
        MenuSearchEntry(id: "action:sound", title: "声音输出", category: "Action", symbol: "speaker", destination: .action("sound"))
    ]
    func testSearchAcrossKindsWithoutLosingDestination() {
        XCTAssertEqual(MenuSearchModel.results(entries, query: " editeur ", recentIDs: []).first?.destination, entries[0].destination)
        XCTAssertEqual(MenuSearchModel.results(entries, query: "工作", recentIDs: []).first?.destination, entries[1].destination)
        XCTAssertEqual(MenuSearchModel.results(entries, query: "sound", recentIDs: []).first?.destination, .action("sound"))
        XCTAssertTrue(MenuSearchModel.results(entries, query: "unmatched", recentIDs: []).isEmpty)
    }
    func testRecentEntriesAreUniqueAvailableAndOrdered() {
        let results = MenuSearchModel.results(entries + entries, query: " \n", recentIDs: ["missing", "action:sound", "action:sound", "app:editor"])
        XCTAssertEqual(results.map(\.id), ["action:sound", "app:editor"])
        XCTAssertTrue(MenuSearchModel.results(entries, query: "", recentIDs: []).isEmpty)
        XCTAssertEqual(MenuSearchModel.results(entries + entries, query: "Action", recentIDs: []).count, 1)
    }
    @MainActor func testHistoryMovesLatestToFrontPersistsAndRemainsBounded() {
        let name = "FuseBar.SearchTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let history = MenuSearchHistory(defaults: defaults)
        for index in 0..<30 { history.record("action:\(index)") }
        history.record("action:20")
        XCTAssertEqual(history.ids.count, 20)
        XCTAssertEqual(history.ids.first, "action:20")
        XCTAssertEqual(Set(history.ids).count, 20)
        XCTAssertEqual(MenuSearchHistory(defaults: defaults).ids, history.ids)
    }
}
