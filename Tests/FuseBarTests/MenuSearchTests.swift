import XCTest
@testable import FuseBar

final class MenuSearchTests: XCTestCase {
    private let entries = [
        MenuSearchEntry(id: "app:editor", title: "Éditeur", category: "Application", symbol: "app", destination: .application(URL(fileURLWithPath: "/Applications/Editor.app"))),
        MenuSearchEntry(id: "file:work", title: "工作目录", category: "Files", symbol: "folder", destination: .file(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)),
        MenuSearchEntry(id: "action:sound", title: "声音输出", category: "Action", symbol: "speaker", destination: .action("sound"))
    ]
    func testSearchAcrossKindsWithoutLosingDestination() {
        XCTAssertEqual(MenuSearchModel.results(entries, query: " editeur ").first?.destination, entries[0].destination)
        XCTAssertEqual(MenuSearchModel.results(entries, query: "工作").first?.destination, entries[1].destination)
        XCTAssertEqual(MenuSearchModel.results(entries, query: "sound").first?.destination, .action("sound"))
        XCTAssertTrue(MenuSearchModel.results(entries, query: "unmatched").isEmpty)
    }
    func testEmptyQueryHasNoResultsAndDuplicatesCollapse() {
        XCTAssertTrue(MenuSearchModel.results(entries, query: "").isEmpty)
        XCTAssertTrue(MenuSearchModel.results(entries, query: " \n").isEmpty)
        XCTAssertEqual(MenuSearchModel.results(entries + entries, query: "Action").count, 1)
    }
}
