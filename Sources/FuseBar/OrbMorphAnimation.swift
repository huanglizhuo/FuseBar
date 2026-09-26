import SwiftUI

// Frame-by-frame convergence animation for the guide hero: the four system icons
// morph into the real orb. The architecture follows the MIT-licensed
// CircleStatusBar reference (github.com/artemnovichkov/CircleStatusBar): a pure
// pose function computes every element's geometry from a timestamp, driven by a
// timeline. No accumulated error, any moment is sampleable and testable.

/// Small, dependency-free math toolbox. Every function is pure.
enum OrbMorphEasing {
    /// Normalized progress of `time` within `window`, clamped to 0…1.
    static func progress(_ time: TimeInterval, in window: ClosedRange<TimeInterval>) -> Double {
        guard window.upperBound > window.lowerBound else { return time >= window.upperBound ? 1 : 0 }
        return min(1, max(0, (time - window.lowerBound) / (window.upperBound - window.lowerBound)))
    }

    /// Hermite curve with zero velocity at both ends.
    static func smoothstep(_ p: Double) -> Double { p * p * (3 - 2 * p) }

    /// Cubic ease-out: starts fast, decelerates into the end.
    static func easeOut(_ p: Double) -> Double { 1 - pow(1 - p, 3) }

    /// Cubic ease-in-out.
    static func easeInOut(_ p: Double) -> Double { p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2 }

    static func mix(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * p }

    static func mix(_ a: CGPoint, _ b: CGPoint, _ p: Double) -> CGPoint {
        CGPoint(x: mix(a.x, b.x, p), y: mix(a.y, b.y, p))
    }

    /// Quadratic Bézier flight path between two points.
    static func quadratic(_ start: CGPoint, _ control: CGPoint, _ end: CGPoint, _ p: Double) -> CGPoint {
        let q = 1 - p
        return CGPoint(x: q * q * start.x + 2 * q * p * control.x + p * p * end.x,
                       y: q * q * start.y + 2 * q * p * control.y + p * p * end.y)
    }

    /// Exponentially decaying sine used as a cheap spring overshoot; zero before `start`.
    static func dampedOscillation(_ time: TimeInterval, start: TimeInterval, amplitude: Double, decay: Double, frequency: Double) -> Double {
        guard time >= start else { return 0 }
        return amplitude * exp(-decay * (time - start)) * sin(frequency * (time - start))
    }
}

/// Key times for the convergence, in seconds.
enum OrbMorphChoreography {
    static let duration: TimeInterval = 2.6
    static let iconSize: CGFloat = 16
    static let orbSide: CGFloat = 32

    static let bluetoothFade = 0.2...0.7
    static let speakerDissolve = 0.3...0.9
    static let wifiFlight = 0.4...1.3
    static let batteryDissolve = 0.5...1.0
    static let dotLaunch = 0.45
    static let dotStagger = 0.09
    static let dotFlight = 0.75
    static let valueArc = 0.9...1.8
    static let trackFade = 1.8...2.1
    static let crossfade = 2.2...2.5
}

/// Canvas geometry derived from the shared orb constants: start icon positions on
/// the left, the final orb horizontally centered at its real size and proportions.
struct OrbMorphLayout {
    let size: CGSize
    let orbCenter: CGPoint
    /// Start positions in story order: wifi, bluetooth, speaker, battery.
    let starts: [CGPoint]

    var scale: CGFloat { OrbMorphChoreography.orbSide / OrbGeometry.canvasSpace }
    var ringRadius: CGFloat { OrbGeometry.ringRadius * scale }
    var ringLineWidth: CGFloat { OrbGeometry.ringLineWidth * scale }
    var dotDiameter: CGFloat { OrbGeometry.dotDiameter * scale }
    var wifiSymbolSize: CGFloat { OrbGeometry.wifiSymbolSize * scale }

    /// The real orb's ring sits above its frame center (the bottom slot needs the
    /// space below), so the crossfaded OrbView frame centers here to land its ring
    /// exactly on `orbCenter` — otherwise the handover reads as a slight settle.
    var orbFrameCenter: CGPoint {
        CGPoint(x: orbCenter.x,
                y: orbCenter.y + (OrbGeometry.canvasSpace / 2 - OrbGeometry.center.y) * scale)
    }

    static func layout(in size: CGSize) -> OrbMorphLayout {
        let midY = size.height / 2
        let starts = (0..<4).map { CGPoint(x: 28 + CGFloat($0) * 34, y: midY) }
        return OrbMorphLayout(size: size,
                              orbCenter: CGPoint(x: size.width / 2, y: midY),
                              starts: starts)
    }

    /// Where volume dot `index` lands: on the ring at the orb's own dot angles.
    func dotCenter(_ index: Int) -> CGPoint {
        let angle = OrbGeometry.dotAngles[index] * .pi / 180
        return CGPoint(x: orbCenter.x + ringRadius * cos(angle), y: orbCenter.y + ringRadius * sin(angle))
    }
}

/// The instantaneous layout of every element at `time`.
struct OrbMorphPose {
    struct Glyph {
        var center: CGPoint
        var scale: CGFloat
        var opacity: Double
    }
    struct Dot {
        var center: CGPoint
        var opacity: Double
    }

    let wifi: Glyph
    let bluetooth: Glyph
    let speaker: Glyph
    let battery: Glyph
    let dots: [Dot]
    /// Fraction of the ring the value arc covers (0…snapshot battery fraction).
    let valueTrim: Double
    /// Background track opacity (0…OrbGeometry.trackOpacity).
    let trackOpacity: Double
    /// Blend to the real OrbView for a pixel-perfect landing.
    let crossfade: Double
}

extension OrbMorphPose {
    init(time: TimeInterval, layout: OrbMorphLayout, snapshot: StatusSnapshot, preferences: IndicatorPreferences) {
        let c = OrbMorphChoreography.self
        let e = OrbMorphEasing.self

        let wifiFly = e.progress(time, in: c.wifiFlight)
        let wifiSettle = 1 + 0.12 * e.dampedOscillation(time, start: c.wifiFlight.upperBound, amplitude: 1, decay: 9, frequency: 16)
        wifi = OrbMorphPose.Glyph(
            center: e.mix(layout.starts[0], layout.orbCenter, e.easeInOut(wifiFly)),
            scale: e.mix(1, layout.wifiSymbolSize / c.iconSize, wifiFly) * wifiSettle,
            opacity: 1)

        let btFade = e.progress(time, in: c.bluetoothFade)
        // The orb never shows Bluetooth; the icon only drifts slightly while fading out.
        bluetooth = OrbMorphPose.Glyph(
            center: e.mix(layout.starts[1], e.mix(layout.starts[1], layout.orbCenter, 0.2), e.easeOut(btFade)),
            scale: 1,
            opacity: 1 - e.easeOut(btFade))

        let speakerFade = e.progress(time, in: c.speakerDissolve)
        speaker = OrbMorphPose.Glyph(center: layout.starts[2], scale: e.mix(1, 0.3, e.easeOut(speakerFade)), opacity: 1 - e.easeOut(speakerFade))

        let batteryFade = e.progress(time, in: c.batteryDissolve)
        battery = OrbMorphPose.Glyph(center: layout.starts[3], scale: e.mix(1, 0.25, e.easeOut(batteryFade)), opacity: 1 - e.easeOut(batteryFade))

        // The speaker dissolves into the orb's own volume dots: one flight per dot,
        // right to left, along an arc that sweeps under the forming ring.
        let filled = snapshot.volumeDots(preferences) ?? 0
        dots = (0..<4).map { index in
            let launch = c.dotLaunch + Double(index) * c.dotStagger
            let flight = e.progress(time, in: launch...(launch + c.dotFlight))
            let target = layout.dotCenter(index)
            let control = CGPoint(x: (layout.starts[2].x + target.x) / 2, y: max(layout.starts[2].y, target.y) + 14)
            let finalOpacity = index < filled ? 1 : OrbGeometry.dimDotOpacity
            return OrbMorphPose.Dot(center: e.quadratic(layout.starts[2], control, target, e.easeInOut(flight)),
                                    opacity: e.mix(0, finalOpacity, min(1, flight * 2)))
        }

        valueTrim = e.easeOut(e.progress(time, in: c.valueArc)) * snapshot.battery.fraction
        trackOpacity = OrbGeometry.trackOpacity * e.easeOut(e.progress(time, in: c.trackFade))
        crossfade = e.smoothstep(e.progress(time, in: c.crossfade))
    }
}

/// Guide hero: four system icons converge into the real orb, then hold. Replays on
/// every guide appearance. Reduce Motion and offscreen previews (galleries, README
/// renders — their hosting windows never tick a TimelineView) keep the static row.
struct OrbMorphHero: View {
    let snapshot: StatusSnapshot
    var preferences = IndicatorPreferences()
    var preview = false
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if preview || reduceMotion {
                staticRow.frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                // The timeline keeps ticking after the duration but the scene then
                // renders only the static landed orb; the guide page is short-lived.
                TimelineView(.animation) { context in
                    OrbMorphScene(time: context.date.timeIntervalSince(start),
                                  layout: OrbMorphLayout.layout(in: proxy.size),
                                  snapshot: snapshot, preferences: preferences)
                }
            }
        }
    }

    private var staticRow: some View {
        HStack(spacing: 13) {
            ForEach(["wifi", StatusSymbols.bluetooth, "speaker.wave.2.fill", "battery.75percent"], id: \.self) { Image(systemName: $0) }
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            orb
        }
    }

    private var orb: some View {
        OrbView(snapshot: snapshot, preferences: preferences, batteryRingTint: true).frame(width: OrbMorphChoreography.orbSide, height: OrbMorphChoreography.orbSide)
    }
}

/// One frame of the convergence; renders the real OrbView once fully crossfaded.
private struct OrbMorphScene: View {
    let time: TimeInterval
    let layout: OrbMorphLayout
    let snapshot: StatusSnapshot
    let preferences: IndicatorPreferences

    var body: some View {
        let pose = OrbMorphPose(time: time, layout: layout, snapshot: snapshot, preferences: preferences)
        return ZStack {
            if pose.crossfade < 1 {
                OrbMorphCanvas(pose: pose, layout: layout, snapshot: snapshot)
                    .opacity(1 - pose.crossfade)
            }
            if pose.crossfade > 0 {
                orb.opacity(pose.crossfade).position(layout.orbFrameCenter)
            }
        }
    }

    private var orb: some View {
        OrbView(snapshot: snapshot, preferences: preferences, batteryRingTint: true)
            .frame(width: OrbMorphChoreography.orbSide, height: OrbMorphChoreography.orbSide)
    }
}

private struct OrbMorphCanvas: View {
    let pose: OrbMorphPose
    let layout: OrbMorphLayout
    let snapshot: StatusSnapshot

    var body: some View {
        ZStack {
            track
            valueArc
            ForEach(pose.dots.indices, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(pose.dots[index].opacity))
                    .frame(width: layout.dotDiameter, height: layout.dotDiameter)
                    .position(pose.dots[index].center)
            }
            glyph("wifi", pose.wifi)
            glyph(StatusSymbols.bluetooth, pose.bluetooth)
            glyph("speaker.wave.2.fill", pose.speaker)
            glyph("battery.75percent", pose.battery)
        }
    }

    private var track: some View {
        ring(fraction: 1).stroke(Color.primary.opacity(pose.trackOpacity),
                                 style: StrokeStyle(lineWidth: layout.ringLineWidth, lineCap: .round))
    }

    private var valueArc: some View {
        ring(fraction: pose.valueTrim).stroke(Color.primary,
                                              style: StrokeStyle(lineWidth: layout.ringLineWidth, lineCap: .round))
    }

    private func ring(fraction: Double) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }
        path.addArc(center: layout.orbCenter, radius: layout.ringRadius,
                    startAngle: .degrees(OrbGeometry.ringStartAngle),
                    endAngle: .degrees(OrbGeometry.ringStartAngle + OrbGeometry.ringSweep * fraction),
                    clockwise: false)
        return path
    }

    private func glyph(_ name: String, _ glyph: OrbMorphPose.Glyph) -> some View {
        Image(systemName: name)
            .font(.system(size: OrbMorphChoreography.iconSize * glyph.scale))
            .foregroundStyle(Color.primary.opacity(glyph.opacity))
            .position(glyph.center)
    }
}
