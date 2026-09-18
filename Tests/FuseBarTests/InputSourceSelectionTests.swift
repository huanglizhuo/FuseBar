import XCTest
@testable import FuseBar

final class InputSourceSelectionTests: XCTestCase {
    @MainActor func testFocusFailureDoesNotBlockActualSelection() async {
        var events: [String] = []
        let result = await InputSourceSelection.perform(restoreFocus: {
            // Simulate macOS declining/delaying activation: no focus change occurs.
            events.append("attempt-focus")
        }, select: {
            events.append("select-source")
            return true
        })
        XCTAssertEqual(result, true)
        XCTAssertEqual(events, ["attempt-focus", "select-source"])
    }
    @MainActor func testReportsRealSelectionFailureAndCancelsStaleRequest() async {
        let failure = await InputSourceSelection.perform(restoreFocus: {}, select: { false })
        XCTAssertEqual(failure, false)
        var selections = 0
        let pending = Task { @MainActor in
            await InputSourceSelection.perform(restoreFocus: {}, select: { selections += 1; return true })
        }
        pending.cancel()
        let result = await pending.value
        XCTAssertNil(result)
        XCTAssertEqual(selections, 0)
    }
}
