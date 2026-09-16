import XCTest
@testable import FuseBar

final class StatusModelTests: XCTestCase {
    func testHotspotPathOverridesMissingCoreWLANAssociation() {
        let hotspot = SystemReader.resolveWiFi(mode: .none, name: nil, rssi: 0,
            path: WiFiPathState(connected: true, expensive: true))
        XCTAssertEqual(hotspot.connection, .connected)
        XCTAssertTrue(hotspot.hotspotStyle)
        XCTAssertEqual(StatusSymbols.wifi(hotspot), "personalhotspot")
        var snapshot = StatusSnapshot.normal
        snapshot.wifi = hotspot
        XCTAssertEqual(snapshot.badge(IndicatorPreferences()), .none)
        let regular = SystemReader.resolveWiFi(mode: .none, name: nil, rssi: -65,
            path: WiFiPathState(connected: true, expensive: false))
        XCTAssertEqual(StatusSymbols.wifi(regular), "wifi")
        XCTAssertEqual(regular.bars, 2)
    }

    func testWiFiPathDoesNotTurnAssociationWithoutInternetIntoDisconnection() {
        let connected = SystemReader.resolveWiFi(mode: .station, name: nil, rssi: -80,
            path: WiFiPathState(connected: false, expensive: true))
        XCTAssertEqual(connected.connection, .connected)
        XCTAssertFalse(connected.hotspotStyle)
        XCTAssertEqual(SystemReader.resolveWiFi(mode: .none, name: nil, rssi: 0, path: nil).connection, .unknown)
        XCTAssertEqual(SystemReader.resolveWiFi(mode: .none, name: nil, rssi: 0,
            path: WiFiPathState(connected: false, expensive: false)).connection, .disconnected)
    }

    func testVolumeDotThresholdsAndUnreadableVolume() {
        for (volume, dots): (Float, Int) in [(0, 0), (0.01, 1), (0.25, 1), (0.26, 2),
                                            (0.5, 2), (0.51, 3), (0.75, 3), (0.76, 4), (1, 4), (2, 4)] {
            XCTAssertEqual(SoundStatus(available: true, volume: volume).volumeDots, dots)
        }
        XCTAssertNil(SoundStatus(available: true).volumeDots)
        XCTAssertNil(SoundStatus(available: true, volume: .nan).volumeDots)
        XCTAssertNil(SoundStatus(volume: 0.5).volumeDots)
        var status = StatusSnapshot.normal
        XCTAssertEqual(status.volumeDots(IndicatorPreferences()), 2)
        XCTAssertNil(status.volumeDots(IndicatorPreferences(sound: false)))
        status.sound.muted = true
        XCTAssertNil(status.volumeDots(IndicatorPreferences()))
        status.sound.muted = false
        status.battery.charging = true
        XCTAssertNil(status.volumeDots(IndicatorPreferences()))
        status.battery.charging = false
        status.wifi.connection = .disconnected
        XCTAssertNil(status.volumeDots(IndicatorPreferences()))
    }

    func testLowBatteryBoundariesAndExternalPower() {
        for (level, low, critical) in [(0, true, true), (9, true, true), (10, true, false), (19, true, false), (20, false, false)] {
            var battery = BatteryStatus(availability: .available, level: level)
            XCTAssertEqual(battery.low, low, "level \(level)")
            XCTAssertEqual(battery.critical, critical, "level \(level)")
            battery.externalPower = true
            XCTAssertFalse(battery.low)
            XCTAssertFalse(battery.critical)
        }
    }

    func testUnknownAndDesktopBatteryAreNotLowBattery() {
        XCTAssertFalse(BatteryStatus().critical)
        XCTAssertFalse(BatteryStatus(availability: .unavailable).low)
        XCTAssertEqual(BatteryStatus(availability: .unavailable).detail, L("无内置电池"))
    }

    func testBatteryFractionClampsInvalidHardwareValues() {
        XCTAssertEqual(BatteryStatus(level: -3).fraction, 0)
        XCTAssertEqual(BatteryStatus(level: 130).fraction, 1)
    }

    func testSSIDRedactionDoesNotImplyDisconnection() {
        let wifi = WiFiStatus(connection: .connected, rssi: -65)
        XCTAssertEqual(wifi.detail, L("已连接 · 网络名称暂不可用"))
        XCTAssertEqual(wifi.bars, 2)
    }

    func testRSSIBoundariesAndMissingValue() {
        XCTAssertEqual(WiFiStatus(rssi: -60).bars, 3)
        XCTAssertEqual(WiFiStatus(rssi: -61).bars, 2)
        XCTAssertEqual(WiFiStatus(rssi: -75).bars, 2)
        XCTAssertEqual(WiFiStatus(rssi: -76).bars, 1)
        XCTAssertEqual(WiFiStatus().bars, 0)
    }

    func testAlertPriorityRespectsDisabledIndicators() {
        var status = StatusSnapshot.normal
        status.battery.level = 7
        status.wifi.connection = .disconnected
        status.sound.muted = true
        var preferences = IndicatorPreferences()
        XCTAssertEqual(status.badge(preferences), .critical)
        XCTAssertEqual(status.headline(preferences), L("电量不足 10%，请连接电源"))
        preferences.battery = false
        XCTAssertEqual(status.badge(preferences), .networkWarning)
        XCTAssertEqual(status.headline(preferences), L("Wi-Fi 尚未连接"))
        preferences.wifi = false
        XCTAssertEqual(status.badge(preferences), .muted)
        XCTAssertEqual(status.headline(preferences), L("声音已静音"))
    }

    func testBottomSlotSelectsOneStatusAndRevealsTheNextWhenResolved() {
        var status = StatusSnapshot.normal
        let preferences = IndicatorPreferences()
        status.battery.level = 7
        status.wifi.connection = .disconnected
        status.sound.muted = true
        XCTAssertEqual(status.badge(preferences), .critical)
        status.battery.level = 16
        XCTAssertEqual(status.badge(preferences), .networkWarning)
        status.wifi.connection = .connected
        XCTAssertEqual(status.badge(preferences), .lowBattery)
        status.battery.externalPower = true
        status.battery.charging = true
        XCTAssertEqual(status.badge(preferences), .charging)
        status.battery.charging = false
        XCTAssertEqual(status.badge(preferences), .muted)
        status.sound.muted = false
        XCTAssertEqual(status.badge(preferences), .none)
    }

    func testBluetoothDoesNotOccupyBottomSlotOrCountAsVisibleIndicator() {
        let status = StatusSnapshot.normal
        let preferences = IndicatorPreferences(battery: false, wifi: false, bluetooth: true, sound: false)
        XCTAssertEqual(status.badge(preferences), .none)
        XCTAssertFalse(preferences.anyEnabled)
        XCTAssertTrue(status.accessibilitySummary(preferences).contains("AirPods Pro"))
    }

    func testDisabledSoundDoesNotTakeBottomSlotAndHiddenStatusesStayInSnapshot() {
        var status = StatusSnapshot.normal
        status.battery.charging = true
        status.battery.externalPower = true
        status.sound.muted = true
        XCTAssertEqual(status.badge(IndicatorPreferences()), .charging)
        XCTAssertTrue(status.accessibilitySummary(IndicatorPreferences()).contains(status.sound.detail))
        let preferences = IndicatorPreferences(battery: false, wifi: false, sound: false)
        XCTAssertEqual(status.badge(preferences), .none)
        XCTAssertTrue(status.sound.effectivelyMuted)
    }

    func testZeroVolumeAndUnknownMute() {
        XCTAssertTrue(SoundStatus(available: true, volume: 0).effectivelyMuted)
        XCTAssertFalse(SoundStatus().effectivelyMuted)
    }

    func testAllIndicatorsCanBeHiddenWithoutFalseHealthyClaim() {
        let preferences = IndicatorPreferences(battery: false, wifi: false, bluetooth: false, sound: false)
        XCTAssertEqual(StatusSnapshot.normal.accessibilitySummary(preferences), "FuseBar")
        XCTAssertEqual(StatusSnapshot.normal.headline(preferences), L("所有图标指标已隐藏"))
    }

    func testChargingBadgeIsNotCriticalWhilePluggedIn() {
        var status = StatusSnapshot.normal
        status.battery = BatteryStatus(availability: .available, level: 5, charging: true, externalPower: true)
        XCTAssertEqual(status.badge(IndicatorPreferences()), .charging)
    }

    func testReadOnlySystemAdaptersReturnBoundedValues() {
        // Exercise real framework bridging, including CoreAudio CF ownership, without writing settings.
        for _ in 0..<5 {
            let status = SystemReader.read(bluetoothState: .permissionRequired)
            XCTAssertTrue((0...1).contains(status.battery.fraction))
            XCTAssertTrue((0...3).contains(status.wifi.bars))
            if let volume = status.sound.volume { XCTAssertTrue((0...1).contains(volume)) }
            XCTAssertEqual(status.bluetooth.state, .permissionRequired)
            XCTAssertTrue(status.bluetooth.devices.isEmpty)
        }
    }

    @MainActor func testPreferencesSurviveStoreRecreation() {
        let suite = "FuseBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = StatusStore(defaults: defaults, demo: true)
        first.preferences.wifi = false
        first.preferences.sound = false
        let second = StatusStore(defaults: defaults, demo: true)
        XCTAssertFalse(second.preferences.wifi)
        XCTAssertFalse(second.preferences.sound)
        XCTAssertTrue(second.preferences.battery)
    }
}
