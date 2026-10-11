import SwiftUI

/// Public SF Symbols available on the macOS 14 deployment target.
enum StatusSymbols {
    static let charging = "bolt.fill"
    // SF Symbols has no Bluetooth glyph; these app-defined names resolve to the
    // drawn rune in StatusIcon.
    static let bluetooth = "fusebar.bluetooth"
    static let bluetoothOff = "fusebar.bluetooth.slash"

    static func battery(_ status: BatteryStatus) -> String {
        guard status.availability == .available else { return "questionmark.circle" }
        if status.charging { return "battery.100percent.bolt" }
        switch status.level {
        case ..<10: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    static func wifi(_ status: WiFiStatus) -> String {
        switch status.connection {
        case .connected: return status.pathUnavailable ? "wifi.exclamationmark" : status.hotspotStyle ? "personalhotspot" : "wifi"
        case .off: return "wifi.slash"
        case .disconnected: return "wifi.exclamationmark"
        case .unknown, .unavailable: return "questionmark.circle"
        }
    }

    static func sound(_ status: SoundStatus) -> String {
        guard status.available else { return "questionmark.circle" }
        if status.effectivelyMuted { return "speaker.slash.fill" }
        guard let volume = status.volume else { return "speaker.fill" }
        return volume < 0.34 ? "speaker.wave.1.fill" : volume < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}

/// Orb geometry in the 22-unit canvas space, shared by the status item, the guide
/// hero animation and the fixture gallery so every rendering lands on the same orb.
enum OrbGeometry {
    /// The 22-unit canvas space the geometry is expressed in.
    static let canvasSpace: CGFloat = 22
    static let center = CGPoint(x: 11, y: 10)
    static let ringRadius: CGFloat = 7.5
    static let ringLineWidth: CGFloat = 1.4
    static let emphasizedRingLineWidth: CGFloat = 1.7
    static let ringStartAngle: Double = 145
    static let ringSweep: Double = 250
    static let dotAngles: [Double] = [125, 102, 79, 56]
    static let dotDiameter: CGFloat = 1.3
    static let dimDotOpacity: Double = 0.22
    static let trackOpacity: Double = 0.18
    static let wifiSymbolSize: CGFloat = 8
    /// Half-angle of the top opening that frames the battery percentage; condensed
    /// digits (compressed for "100") clear the ring's round caps at this width.
    static let numberOpening: Double = 40
    /// Canvas text inks about 0.25 above its anchor, so the digits center near y 3.45.
    static let numberCenter = CGPoint(x: 11, y: 3.7)

    /// Angle ranges the ring covers at `fraction`. An opened ring splits the 250° sweep
    /// around the top opening into two equal halves, each exactly half of the gauge.
    static func arcs(_ fraction: Double, opened: Bool) -> [ClosedRange<Double>] {
        let starts = opened ? [ringStartAngle, 270 + numberOpening] : [ringStartAngle]
        let span = (ringSweep - (opened ? 2 * numberOpening : 0)) / Double(starts.count)
        var remaining = span * Double(starts.count) * min(1, max(0, fraction))
        return starts.compactMap { start in
            defer { remaining -= span }
            return remaining > 0 ? start...(start + min(remaining, span)) : nil
        }
    }
}

/// Single geometry shared by the actual status item, onboarding and the fixture gallery.
struct OrbView: View {
    let snapshot: StatusSnapshot
    var preferences = IndicatorPreferences()
    // Menu-bar templates need opaque mask ink; content views retain semantic color.
    // A low battery overrides both with red; the status item then drops template mode.
    var ink: Color = .primary
    var emphasized = false
    // The status item stays monochrome while charging; colored contexts (panel
    // header, gallery) draw the charging arc green.
    var batteryRingTint = false
    var inputSource: KeyboardSource?

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 22
            context.scaleBy(x: scale, y: scale)
            let ink = snapshot.batteryAlert(preferences) ? Color.red : self.ink
            let weight: Font.Weight = emphasized ? .bold : .semibold
            func symbol(_ name: String, x: CGFloat, y: CGFloat, size: CGFloat,
                        value: Double? = nil, weight: Font.Weight? = nil) {
                let glyph = Text(Image(systemName: name, variableValue: value).symbolRenderingMode(.monochrome))
                    .font(.system(size: size, weight: weight ?? (emphasized ? .bold : .semibold))).foregroundStyle(ink)
                context.draw(glyph, at: CGPoint(x: x, y: y))
            }
            let number = snapshot.batteryNumber(preferences)
            func arc(_ fraction: Double, _ color: Color, dashed: Bool = false) {
                // A symmetric 110° gap holds exactly one status symbol on the vertical axis.
                for range in OrbGeometry.arcs(fraction, opened: number != nil) {
                    var path = Path()
                    path.addArc(center: OrbGeometry.center, radius: OrbGeometry.ringRadius,
                                startAngle: .degrees(range.lowerBound), endAngle: .degrees(range.upperBound), clockwise: false)
                    context.stroke(path, with: .color(color),
                                   style: StrokeStyle(lineWidth: emphasized ? OrbGeometry.emphasizedRingLineWidth : OrbGeometry.ringLineWidth, lineCap: .round, dash: dashed ? [1, 2] : []))
                }
            }
            if preferences.battery {
                switch snapshot.battery.availability {
                case .available:
                    arc(1, ink.opacity(OrbGeometry.trackOpacity))
                    arc(snapshot.battery.fraction, batteryRingTint && snapshot.battery.charging ? .green : ink)
                case .unknown: arc(1, ink.opacity(0.55), dashed: true)
                case .unavailable: break
                }
            }
            if let number {
                // Condensed digits fit the opening; "100" needs the narrower compressed cut.
                let font: Font = number.count > 2 ? .system(size: 5, weight: weight).width(.compressed)
                    : .system(size: 6, weight: weight).width(.condensed)
                context.draw(Text(number).font(font).monospacedDigit().foregroundStyle(ink), at: OrbGeometry.numberCenter)
            }
            if let inputSource {
                if let icon = inputSource.templateIcon?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    var glyph = context.resolve(Image(decorative: icon, scale: 1).renderingMode(.template))
                    glyph.shading = .color(ink)
                    context.draw(glyph, in: CGRect(x: 7.5, y: 6.5, width: 7, height: 7))
                } else {
                    context.draw(Text(inputSource.fallback).font(.system(size: 6, weight: .semibold)).foregroundStyle(ink), at: CGPoint(x: 11, y: 10))
                }
            } else if preferences.center == .sound && preferences.sound {
                symbol(StatusSymbols.sound(snapshot.sound), x: 11, y: 10, size: 7)
            } else if preferences.center == .network && preferences.wifi {
                switch snapshot.wifi.connection {
                case .connected:
                    // The menu bar keeps the plain glyph; a missing path shows in the bottom alert slot.
                    symbol(snapshot.wifi.hotspotStyle ? "personalhotspot" : "wifi", x: OrbGeometry.center.x, y: OrbGeometry.center.y, size: snapshot.wifi.hotspotStyle ? 6.5 : OrbGeometry.wifiSymbolSize,
                           value: snapshot.wifi.hotspotStyle || snapshot.wifi.bars == 0 ? nil : Double(snapshot.wifi.bars) / 3)
                case .disconnected:
                    // The full wifi.exclamationmark is reserved for the larger popover row.
                    symbol("xmark", x: 11, y: 10, size: 6)
                case .off: symbol("wifi.slash", x: 11, y: 10, size: 8)
                case .unknown, .unavailable: symbol("questionmark", x: 11, y: 10, size: 7)
                }
            }
            if let number = snapshot.bottomNumber(preferences) {
                context.draw(Text(number).font(.system(size: number.count > 2 ? 5.4 : 6, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(ink), at: CGPoint(x: 11, y: 18.1))
            } else {
                switch snapshot.badge(preferences) {
                case .critical, .networkWarning, .lowBattery:
                    symbol("exclamationmark", x: 11, y: 18.1, size: 6.5, weight: .bold)
                case .charging:
                    symbol(StatusSymbols.charging, x: 11, y: 18.1, size: 6.5, weight: .regular)
                case .muted:
                    symbol("speaker.slash.fill", x: 11, y: 18.1, size: 5.5, weight: .regular)
                case .none:
                    if let filled = snapshot.volumeDots(preferences) {
                        for index in 0..<4 {
                            let angle = OrbGeometry.dotAngles[index] * .pi / 180
                            let center = CGPoint(x: OrbGeometry.center.x + OrbGeometry.ringRadius * cos(angle),
                                                 y: OrbGeometry.center.y + OrbGeometry.ringRadius * sin(angle))
                            let dot = Path(ellipseIn: CGRect(x: center.x - OrbGeometry.dotDiameter / 2, y: center.y - OrbGeometry.dotDiameter / 2,
                                                             width: OrbGeometry.dotDiameter, height: OrbGeometry.dotDiameter))
                            context.fill(dot, with: .color(ink.opacity(index < filled ? 1 : OrbGeometry.dimDotOpacity)))
                        }
                    }
                }
            }
            if inputSource == nil && !preferences.centerEnabled && (!preferences.battery || snapshot.battery.availability == .unavailable) {
                // A stable neutral anchor keeps the app reachable even when all indicators are off.
                symbol("circle", x: 11, y: 10, size: 9, weight: .regular)
            }
        }
        .accessibilityLabel(snapshot.accessibilitySummary(preferences))
    }
}
