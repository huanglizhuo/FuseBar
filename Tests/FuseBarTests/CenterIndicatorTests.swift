import AppKit
import SwiftUI
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
    func testOrbPresentationIgnoresDetailsAndReadingsWithinVisibleBuckets() {
        let original = StatusSnapshot.normal
        var changed = original
        changed.wifi.rssi = -59
        changed.wifi.name = "Another network"
        changed.bluetooth.devices = ["Another device"]
        changed.sound.deviceName = "Another output"
        changed.sound.deviceUID = "another-id"
        changed.sound.volume = 0.43
        changed.sound.canSetVolume = false
        XCTAssertEqual(OrbPresentation(original, .init(), scale: 2), OrbPresentation(changed, .init(), scale: 2))
        XCTAssertNotEqual(original.accessibilitySummary(.init()), changed.accessibilitySummary(.init()))
        var preferences = IndicatorPreferences()
        preferences.bluetooth = false
        XCTAssertEqual(OrbPresentation(original, .init(), scale: 2), OrbPresentation(original, preferences, scale: 2))
    }

    func testOrbPresentationTracksVisibleStateAndPreferences() {
        let original = StatusSnapshot.normal
        let baseline = OrbPresentation(original, .init(), scale: 2)
        var changes: [StatusSnapshot] = []
        var changed = original; changed.wifi.rssi = -70; changes.append(changed)
        changed = original; changed.wifi.hotspotStyle = true; changes.append(changed)
        changed = original; changed.wifi.pathUnavailable = true; changes.append(changed)
        changed = original; changed.wifi.connection = .off; changes.append(changed)
        changed = original; changed.battery.level = 81; changes.append(changed)
        changed = original; changed.battery.level = 19; changes.append(changed)
        changed = original; changed.battery.availability = .unknown; changes.append(changed)
        changed = original; changed.battery.charging = true; changes.append(changed)
        changed = original; changed.sound.volume = 0.7; changes.append(changed)
        changed = original; changed.sound.muted = true; changes.append(changed)
        for snapshot in changes { XCTAssertNotEqual(baseline, OrbPresentation(snapshot, .init(), scale: 2)) }
        var variants: [IndicatorPreferences] = []
        var preferences = IndicatorPreferences(); preferences.battery = false; variants.append(preferences)
        preferences = .init(); preferences.batteryNumber = false; variants.append(preferences)
        preferences = .init(); preferences.wifi = false; variants.append(preferences)
        preferences = .init(); preferences.sound = false; variants.append(preferences)
        preferences = .init(); preferences.center = .sound; variants.append(preferences)
        preferences = .init(); preferences.bottomIndicator = .volumeLevel; variants.append(preferences)
        for preferences in variants { XCTAssertNotEqual(baseline, OrbPresentation(original, preferences, scale: 2)) }
        XCTAssertNotEqual(baseline, OrbPresentation(original, .init(), scale: 1))
    }

    func testOrbPresentationTracksInputSourceIdentityImageAndFallback() {
        let snapshot = StatusSnapshot.normal
        var source = KeyboardSource(id: "en", name: "English", language: "en")
        let baseline = OrbPresentation(snapshot, .init(), inputSource: source, scale: 2)
        source = KeyboardSource(id: "en", name: "Renamed", language: "en")
        XCTAssertEqual(baseline, OrbPresentation(snapshot, .init(), inputSource: source, scale: 2))
        source = KeyboardSource(id: "zh", name: "Chinese", language: "zh")
        XCTAssertNotEqual(baseline, OrbPresentation(snapshot, .init(), inputSource: source, scale: 2))
        source = KeyboardSource(id: "en", name: "English", language: "en", templateIcon: NSImage(size: NSSize(width: 7, height: 7)))
        XCTAssertNotEqual(baseline, OrbPresentation(snapshot, .init(), inputSource: source, scale: 2))
        let withImage = OrbPresentation(snapshot, .init(), inputSource: source, scale: 2)
        source.templateIcon = NSImage(size: NSSize(width: 7, height: 7))
        XCTAssertNotEqual(withImage, OrbPresentation(snapshot, .init(), inputSource: source, scale: 2))
        source = KeyboardSource(id: "en", name: "English", language: "ja")
        XCTAssertNotEqual(baseline, OrbPresentation(snapshot, .init(), inputSource: source, scale: 2))
    }
    func testOrbPresentationUsesSoundSymbolAndNumericVolumeBuckets() {
        var preferences = IndicatorPreferences()
        preferences.center = .sound
        preferences.sound = true
        var snapshot = StatusSnapshot.normal
        let baseline = OrbPresentation(snapshot, preferences, scale: 2)
        snapshot.sound.volume = 0.49
        XCTAssertEqual(baseline, OrbPresentation(snapshot, preferences, scale: 2))
        snapshot.sound.volume = 0.33
        XCTAssertNotEqual(baseline, OrbPresentation(snapshot, preferences, scale: 2))
        preferences.bottomIndicator = .volumeLevel
        snapshot.sound.volume = 0.42
        let numeric = OrbPresentation(snapshot, preferences, scale: 2)
        snapshot.sound.volume = 0.43
        XCTAssertNotEqual(numeric, OrbPresentation(snapshot, preferences, scale: 2))
        preferences.battery = false
        let hiddenBattery = OrbPresentation(snapshot, preferences, scale: 2)
        snapshot.battery.level = 2
        snapshot.battery.charging = true
        XCTAssertEqual(hiddenBattery, OrbPresentation(snapshot, preferences, scale: 2))
    }
    @MainActor func testEqualPresentationProducesEqualOrbPixels() throws {
        let original = StatusSnapshot.normal
        var changed = original
        changed.wifi.name = "Private network"
        changed.wifi.rssi = -58
        changed.bluetooth.devices = ["Private device"]
        changed.sound.deviceName = "Private output"
        changed.sound.volume = 0.43
        func pixels(_ snapshot: StatusSnapshot) throws -> Data {
            let renderer = ImageRenderer(content: OrbView(snapshot: snapshot, ink: .black, emphasized: true)
                .frame(width: 22, height: 22).environment(\.colorScheme, .light))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            return try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        }
        XCTAssertEqual(OrbPresentation(original, .init(), scale: 2), OrbPresentation(changed, .init(), scale: 2))
        XCTAssertEqual(try pixels(original), try pixels(changed))
    }
}
