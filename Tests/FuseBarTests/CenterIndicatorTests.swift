import XCTest
@testable import FuseBar

final class CenterIndicatorTests: XCTestCase {
    @MainActor func testDefaultPersistenceAndInvalidValueFallback() {
        let name = "FuseBar.CenterTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = StatusStore(defaults: defaults, demo: true)
        XCTAssertEqual(store.preferences.center, .network)
        store.preferences.center = .sound
        XCTAssertEqual(StatusStore(defaults: defaults, demo: true).preferences.center, .sound)
        defaults.set("invalid", forKey: "centerIndicator")
        XCTAssertEqual(StatusStore(defaults: defaults, demo: true).preferences.center, .network)
    }
    func testSelectedIndicatorVisibilityAndSoundStates() {
        var preferences = IndicatorPreferences()
        preferences.wifi = false
        XCTAssertFalse(preferences.centerEnabled)
        preferences.center = .sound
        XCTAssertTrue(preferences.centerEnabled)
        preferences.sound = false
        XCTAssertFalse(preferences.centerEnabled)
        XCTAssertEqual(StatusSymbols.sound(SoundStatus()), "questionmark.circle")
        var sound = StatusSnapshot.normal.sound
        sound.muted = true
        XCTAssertEqual(StatusSymbols.sound(sound), "speaker.slash.fill")
        sound.muted = false
        sound.volume = 0.9
        XCTAssertEqual(StatusSymbols.sound(sound), "speaker.wave.3.fill")
    }
}
