import AppKit
import Carbon
import XCTest
import SwiftUI
@testable import FuseBar

@MainActor private final class InputClientFixture: InputSourceClient {
    let entries = [KeyboardSource(id: "a", name: "ABC", language: "en", icon: nil),
                   KeyboardSource(id: "b", name: "日本語", language: "ja", icon: nil)]
    var selected = "a"
    var reject = false
    func read() -> (sources: [KeyboardSource], currentID: String?) { (entries, selected) }
    func select(_ id: String) -> OSStatus {
        guard !reject, entries.contains(where: { $0.id == id }) else { return OSStatus(paramErr) }
        selected = id
        return noErr
    }
}

final class InputSourceTests: XCTestCase {
    func testFlashOnlyOnChangeAndExpiresAfterTwoSeconds() {
        var state = InputSourcePresentation()
        let now = Date(timeIntervalSince1970: 100)
        state.update("a", now: now)
        XCTAssertFalse(state.visible(always: false, now: now))
        state.update("b", now: now)
        XCTAssertTrue(state.visible(always: false, now: now.addingTimeInterval(1.9)))
        state.update("b", now: now.addingTimeInterval(1))
        XCTAssertFalse(state.visible(always: false, now: now.addingTimeInterval(2)))
        XCTAssertTrue(state.visible(always: true, now: now.addingTimeInterval(10)))
        state.update(nil, now: now)
        XCTAssertFalse(state.visible(always: true, now: now))
    }
    func testRapidChangesExtendLatestFlashAndFallbackLabels() {
        var state = InputSourcePresentation()
        let now = Date()
        state.update("a", now: now)
        state.update("b", now: now)
        state.update("c", now: now.addingTimeInterval(1))
        XCTAssertTrue(state.visible(always: false, now: now.addingTimeInterval(2.5)))
        XCTAssertFalse(state.visible(always: false, now: now.addingTimeInterval(3)))
        XCTAssertEqual(KeyboardSource(id: "a", name: "Chinese", language: "zh-Hans", icon: nil).fallback, "中")
        XCTAssertEqual(KeyboardSource(id: "b", name: "Japanese", language: "ja", icon: nil).fallback, "あ")
        XCTAssertEqual(KeyboardSource(id: "c", name: "Unknown", language: "", icon: nil).fallback, "A")
    }
    @MainActor func testInputSourceImageRendersInOrbCenter() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.black.setFill(); rect.fill(); return true
        }
        let source = KeyboardSource(id: "test", name: "Test", language: "en", icon: image,
                                    templateIcon: SystemInputSourceClient.template(image))
        let renderer = ImageRenderer(content: OrbView(snapshot: .normal,
            preferences: IndicatorPreferences(battery: false, wifi: false, bluetooth: false, sound: false),
            ink: .black, inputSource: source).frame(width: 22, height: 22))
        renderer.scale = 1
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: 11, y: 10)).alphaComponent, 0.9)
    }
    @MainActor func testInputGlyphFollowsLightAndDarkAppearance() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.black.setFill(); rect.fill(); return true
        }
        let source = KeyboardSource(id: "theme", name: "Theme", language: "en", icon: image,
                                    templateIcon: SystemInputSourceClient.template(image))
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: InputSourceGlyph(source: source).frame(width: 16, height: 16)
                .environment(\.colorScheme, scheme))
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let color = try XCTUnwrap(bitmap.colorAt(x: 8, y: 8)?.usingColorSpace(.deviceRGB))
            XCTAssertGreaterThan(color.alphaComponent, 0.8)
            if scheme == .dark { XCTAssertGreaterThan(color.redComponent, 0.8, "Input-source icon must become light in dark appearance") }
            else { XCTAssertLessThan(color.redComponent, 0.2) }
            let orb = ImageRenderer(content: OrbView(snapshot: .normal, inputSource: source)
                .frame(width: 22, height: 22).environment(\.colorScheme, scheme))
            let orbBitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(orb.cgImage))
            let center = try XCTUnwrap(orbBitmap.colorAt(x: 11, y: 10)?.usingColorSpace(.deviceRGB))
            if scheme == .dark { XCTAssertGreaterThan(center.redComponent, 0.8) }
            else { XCTAssertLessThan(center.redComponent, 0.2) }
        }
    }
    @MainActor func testTemplatePreservesWhiteCutouts() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.black.setFill(); rect.fill()
            NSColor.white.setFill(); NSRect(x: 4, y: 4, width: 8, height: 8).fill()
            return true
        }
        let template = try XCTUnwrap(SystemInputSourceClient.template(image))
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(template.cgImage(forProposedRect: nil, context: nil, hints: nil)))
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: 2, y: 2)).alphaComponent, 0.9)
        XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 16, y: 16)).alphaComponent, 0.1)
    }
    @MainActor func testSelectionReadbackFailureAndPreferencePersistence() throws {
        let suite = "FuseBarTests.InputSources.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let client = InputClientFixture()
        let store = InputSourceStore(defaults: defaults, client: client)
        defer { store.stop() }
        store.refresh()
        XCTAssertNil(store.centerSource)
        XCTAssertTrue(store.select("b"))
        XCTAssertEqual(store.currentID, "b")
        XCTAssertEqual(store.centerSource?.id, "b")
        client.reject = true
        XCTAssertFalse(store.select("a"))
        XCTAssertEqual(store.currentID, "b")
        XCTAssertNotNil(store.error)
        store.alwaysShow = true
        let restored = InputSourceStore(defaults: defaults, client: client)
        restored.refresh()
        XCTAssertTrue(restored.alwaysShow)
        XCTAssertEqual(restored.centerSource?.id, "b")
    }
}
