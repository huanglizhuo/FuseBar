import XCTest
import Carbon
@testable import FuseBar

final class CodingWorkspaceTests: XCTestCase {
    private func app(_ id: String, running: Bool = true) -> ShelfApplication {
        ShelfApplication(id: id, name: id, url: nil, running: running)
    }
    func testHomeDeduplicatesRunningAppsAndKeepsRecencyOrder() {
        let running = [app("browser"), app("terminal"), app("browser")]
        XCTAssertEqual(ApplicationShelfModel.home(running: running).map(\.id), ["browser", "terminal"])
        XCTAssertEqual(ApplicationShelfModel.home(running: running, recentIDs: ["terminal"]).map(\.id), ["terminal", "browser"])
    }
    func testStableOrderingPreservesSurvivorsAndAppendsNewApps() {
        let previous = [app("b"), app("a"), app("closed")]
        let current = [app("a"), app("b"), app("c"), app("a")]
        XCTAssertEqual(ApplicationShelfModel.stable(previous: previous, current: current).map(\.id), ["b", "a", "c"])
    }
    func testProjectURLsAllowLocalPreviewButRejectCredentialsAndExecutableSchemes() {
        for value in ["http://localhost:3000", "https://github.com/org/repo", "http://127.0.0.1:8080/path", "https://[::1]:3000"] {
            XCTAssertNotNil(CodingProject.webURL(value), value)
        }
        for value in ["javascript:alert(1)", "file:///tmp/file", "shortcuts://run-shortcut?name=test", "https://user:password@example.com", "https://", "localhost:3000"] {
            XCTAssertNil(CodingProject.webURL(value), value)
        }
        XCTAssertFalse(CodingProject(name: "  ", preview: "", repository: "").valid)
    }
    @MainActor func testProjectsPersistEditRemoveAndRecoverSelection() throws {
        let suite = "FuseBarTests.Projects.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CodingProjects(defaults: defaults)
        let first = CodingProject(name: "One", preview: "http://localhost:3000", repository: "")
        var second = CodingProject(name: "Two", preview: "", repository: "https://github.com/org/repo")
        XCTAssertTrue(store.save(first)); XCTAssertTrue(store.save(second))
        second.name = "Renamed"
        XCTAssertTrue(store.save(second)); XCTAssertEqual(store.items.count, 2)
        let restored = CodingProjects(defaults: defaults)
        XCTAssertEqual(restored.current?.name, "Renamed")
        restored.remove(second.id)
        XCTAssertEqual(restored.current?.id, first.id)
        XCTAssertEqual(CodingProjects(defaults: defaults).current?.id, first.id)
        let invalid = CodingProject(name: "Bad", preview: "file:///secret", repository: "")
        XCTAssertFalse(restored.save(invalid)); XCTAssertEqual(restored.items.count, 1)
    }
    func testShortcutValidationAndSerialization() throws {
        let valid = ShortcutCombination(keyCode: 3, modifiers: UInt32(cmdKey | optionKey), keyLabel: "F")
        XCTAssertTrue(valid.isValid)
        XCTAssertEqual(valid.title, "⌥⌘F")
        XCTAssertEqual(try JSONDecoder().decode(ShortcutCombination.self, from: JSONEncoder().encode(valid)), valid)
        XCTAssertFalse(ShortcutCombination(keyCode: 3, modifiers: 0, keyLabel: "F").isValid)
        XCTAssertFalse(ShortcutCombination(keyCode: 3, modifiers: UInt32(shiftKey | optionKey), keyLabel: "F").isValid)
        XCTAssertFalse(ShortcutCombination(keyCode: 53, modifiers: UInt32(cmdKey | optionKey), keyLabel: "Escape").isValid)
        XCTAssertFalse(ShortcutCombination(keyCode: 12, modifiers: UInt32(cmdKey | controlKey), keyLabel: "Q").isValid)
    }
    @MainActor func testRecorderCapturesCombinationAndEscapeCancels() throws {
        let button = RecordingButton()
        button.idleTitle = "Record"
        var recorded: ShortcutCombination?
        button.receive = { recorded = $0 }
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .option], timestamp: 0, windowNumber: 0, context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
        button.mouseDown(with: key)
        XCTAssertTrue(button.performKeyEquivalent(with: key))
        XCTAssertEqual(recorded?.title, "⌥⌘F")
        XCTAssertFalse(button.recording)
        recorded = nil
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 53))
        button.mouseDown(with: key)
        button.keyDown(with: escape)
        XCTAssertNil(recorded)
        XCTAssertFalse(button.recording)
    }

    @MainActor func testCarbonHotKeyEventInvokesRegisteredAction() throws {
        let suite = "FuseBarTests.Event.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shortcut = GlobalShortcut(defaults: defaults)
        shortcut.start()
        defer { shortcut.clear(); shortcut.stop() }
        shortcut.apply(ShortcutCombination(keyCode: 80, modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey), keyLabel: "F19"))
        XCTAssertTrue(shortcut.active)
        var invocations = 0
        shortcut.onInvoke = { invocations += 1 }
        var event: EventRef?
        XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event), noErr)
        let eventRef = try XCTUnwrap(event)
        defer { ReleaseEvent(eventRef) }
        var id = EventHotKeyID(signature: 0x46555345, id: 1)
        XCTAssertEqual(SetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id), noErr)
        XCTAssertEqual(SendEventToEventTarget(eventRef, GetApplicationEventTarget()), noErr)
        XCTAssertEqual(invocations, 1)
        id.id = 999
        XCTAssertEqual(SetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id), noErr)
        _ = SendEventToEventTarget(eventRef, GetApplicationEventTarget())
        XCTAssertEqual(invocations, 1)
    }

    @MainActor func testHotKeyRegistrationConflictPersistenceAndRelease() throws {
        let suite = "FuseBarTests.Shortcut.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shortcut = GlobalShortcut(defaults: defaults)
        shortcut.start()
        defer { shortcut.stop() }
        let value = ShortcutCombination(keyCode: 79, modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey), keyLabel: "F18")
        shortcut.apply(value)
        XCTAssertTrue(shortcut.active, shortcut.error ?? "")
        XCTAssertEqual(GlobalShortcut(defaults: defaults).combination, value)
        let other = GlobalShortcut(defaults: defaults)
        other.start()
        defer { other.stop() }
        XCTAssertFalse(other.active)
        XCTAssertNotNil(other.error)
        XCTAssertTrue(shortcut.active)
        shortcut.clear()
        XCTAssertNil(defaults.data(forKey: "quickOpenShortcut"))
        other.apply(value)
        XCTAssertTrue(other.active, other.error ?? "")
        other.stop()
        let restored = GlobalShortcut(defaults: defaults)
        restored.start()
        XCTAssertTrue(restored.active, restored.error ?? "")
        restored.clear(); restored.stop()
    }
}
