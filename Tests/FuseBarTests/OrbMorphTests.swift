import XCTest
import CoreGraphics
@testable import FuseBar

/// The guide-hero convergence is a pure function of time: the start pose is the
/// icon row, the final pose lands exactly on the real orb geometry, and nothing
/// moves backwards on the way.
final class OrbMorphTests: XCTestCase {
    private let layout = OrbMorphLayout.layout(in: CGSize(width: 284, height: 48))
    private let snapshot = StatusSnapshot.hero
    private var preferences: IndicatorPreferences { IndicatorPreferences() }

    private func pose(_ time: TimeInterval) -> OrbMorphPose {
        OrbMorphPose(time: time, layout: layout, snapshot: snapshot, preferences: preferences)
    }

    func testStartPoseIsTheIconRow() {
        let p = pose(0)
        XCTAssertEqual(p.wifi.center, layout.starts[0])
        XCTAssertEqual(p.bluetooth.center, layout.starts[1])
        XCTAssertEqual(p.speaker.center, layout.starts[2])
        XCTAssertEqual(p.battery.center, layout.starts[3])
        XCTAssertEqual(p.wifi.opacity, 1)
        XCTAssertEqual(p.bluetooth.opacity, 1)
        XCTAssertEqual(p.speaker.opacity, 1)
        XCTAssertEqual(p.battery.opacity, 1)
        XCTAssertEqual(p.valueTrim, 0)
        XCTAssertEqual(p.trackOpacity, 0)
        XCTAssertEqual(p.crossfade, 0)
        XCTAssertTrue(p.dots.allSatisfy { $0.opacity == 0 }, "dots must not be visible before the speaker dissolves")
    }

    func testFinalPoseLandsOnOrbGeometry() {
        let p = pose(OrbMorphChoreography.duration + 0.5)
        XCTAssertEqual(p.crossfade, 1, "the scene must hand over to the real OrbView")
        XCTAssertEqual(p.valueTrim, snapshot.battery.fraction, accuracy: 1e-9)
        XCTAssertEqual(snapshot.battery.fraction, 1, accuracy: 1e-9, "the hero shows a full battery")
        XCTAssertEqual(p.trackOpacity, OrbGeometry.trackOpacity, accuracy: 1e-9)
        // The merge target is horizontally centered.
        XCTAssertEqual(layout.orbCenter.x, layout.size.width / 2, accuracy: 0.001)
        XCTAssertEqual(p.wifi.center.x, layout.orbCenter.x, accuracy: 0.001)
        XCTAssertEqual(p.wifi.center.y, layout.orbCenter.y, accuracy: 0.001)
        // The crossfaded OrbView frame is offset so its ring center lands on orbCenter;
        // without this the handover reads as a slight vertical settle.
        XCTAssertEqual(layout.orbFrameCenter.y - layout.orbCenter.y,
                       (OrbGeometry.canvasSpace / 2 - OrbGeometry.center.y) * layout.scale, accuracy: 0.001)
        XCTAssertEqual(p.bluetooth.opacity, 0, "the orb never shows Bluetooth")
        XCTAssertEqual(p.speaker.opacity, 0)
        XCTAssertEqual(p.battery.opacity, 0)
        let filled = snapshot.volumeDots(preferences) ?? 0
        XCTAssertEqual(p.dots.count, 4)
        for index in 0..<4 {
            XCTAssertEqual(p.dots[index].center.x, layout.dotCenter(index).x, accuracy: 0.001)
            XCTAssertEqual(p.dots[index].center.y, layout.dotCenter(index).y, accuracy: 0.001)
            XCTAssertEqual(p.dots[index].opacity, index < filled ? 1 : OrbGeometry.dimDotOpacity, accuracy: 1e-9)
        }
    }

    func testRingGrowthNeverReverses() {
        var previousTrim = -1.0
        var previousFade = -1.0
        var time = 0.0
        while time <= OrbMorphChoreography.duration {
            let p = pose(time)
            XCTAssertGreaterThanOrEqual(p.valueTrim, previousTrim - 1e-12)
            XCTAssertGreaterThanOrEqual(p.crossfade, previousFade - 1e-12)
            previousTrim = p.valueTrim
            previousFade = p.crossfade
            time += 0.05
        }
        XCTAssertEqual(previousTrim, snapshot.battery.fraction, accuracy: 1e-9)
    }

    func testEasingPrimitives() {
        XCTAssertEqual(OrbMorphEasing.progress(-1, in: 0...1), 0)
        XCTAssertEqual(OrbMorphEasing.progress(2, in: 0...1), 1)
        XCTAssertEqual(OrbMorphEasing.progress(0.5, in: 0...1), 0.5)
        let start = CGPoint(x: 1, y: 2), control = CGPoint(x: 10, y: 20), end = CGPoint(x: 30, y: 40)
        XCTAssertEqual(OrbMorphEasing.quadratic(start, control, end, 0), start)
        XCTAssertEqual(OrbMorphEasing.quadratic(start, control, end, 1), end)
        XCTAssertEqual(OrbMorphEasing.dampedOscillation(0.5, start: 1, amplitude: 1, decay: 5, frequency: 10), 0)
        XCTAssertNotEqual(OrbMorphEasing.dampedOscillation(1.2, start: 1, amplitude: 1, decay: 5, frequency: 10), 0)
    }
}
