import SwiftUI

/// Public SF Symbols available on the macOS 14 deployment target.
enum StatusSymbols {
    static let charging = "bolt.fill"
    // SF Symbols has no public Bluetooth logo; this is a generic wireless indicator.
    static let bluetooth = "antenna.radiowaves.left.and.right"

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
        case .connected: return status.hotspotStyle ? "personalhotspot" : "wifi"
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

/// Single geometry shared by the actual status item, onboarding and the fixture gallery.
struct OrbView: View {
    let snapshot: StatusSnapshot
    var preferences = IndicatorPreferences()
    // Menu-bar templates need opaque mask ink; content views retain semantic color.
    var ink: Color = .primary
    var emphasized = false
    // The status item renders a monochrome template, so it never tints; colored
    // contexts (panel header, gallery) follow the system battery colors instead.
    var batteryRingTint = false
    var inputSource: KeyboardSource?

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 22
            context.scaleBy(x: scale, y: scale)
            func symbol(_ name: String, x: CGFloat, y: CGFloat, size: CGFloat,
                        value: Double? = nil, weight: Font.Weight? = nil) {
                let glyph = Text(Image(systemName: name, variableValue: value).symbolRenderingMode(.monochrome))
                    .font(.system(size: size, weight: weight ?? (emphasized ? .bold : .semibold))).foregroundStyle(ink)
                context.draw(glyph, at: CGPoint(x: x, y: y))
            }
            let ringTint: Color? = {
                guard batteryRingTint else { return nil }
                switch snapshot.battery.systemTint {
                case .charging: return .green
                case .critical: return .red
                case .none: return nil
                }
            }()
            func arc(_ fraction: Double, opacity: Double, dashed: Bool = false) {
                var path = Path()
                // A symmetric 110° gap holds exactly one status symbol on the vertical axis.
                path.addArc(center: CGPoint(x: 11, y: 10), radius: 7.5,
                            startAngle: .degrees(145), endAngle: .degrees(145 + 250 * fraction), clockwise: false)
                context.stroke(path, with: .color(ink.opacity(opacity)),
                               style: StrokeStyle(lineWidth: emphasized ? 1.7 : 1.4, lineCap: .round, dash: dashed ? [1, 2] : []))
            }
            func valueArc(_ fraction: Double) {
                var path = Path()
                path.addArc(center: CGPoint(x: 11, y: 10), radius: 7.5,
                            startAngle: .degrees(145), endAngle: .degrees(145 + 250 * fraction), clockwise: false)
                context.stroke(path, with: .color((ringTint ?? ink).opacity(1)),
                               style: StrokeStyle(lineWidth: emphasized ? 1.7 : 1.4, lineCap: .round))
            }
            if preferences.battery {
                switch snapshot.battery.availability {
                case .available:
                    arc(1, opacity: 0.18)
                    if snapshot.battery.fraction > 0 { valueArc(snapshot.battery.fraction) }
                case .unknown: arc(1, opacity: 0.55, dashed: true)
                case .unavailable: break
                }
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
                    symbol(StatusSymbols.wifi(snapshot.wifi), x: 11, y: 10, size: snapshot.wifi.hotspotStyle ? 6.5 : 8,
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
                            let angle = Double(125 - index * 23) * .pi / 180
                            let center = CGPoint(x: 11 + 7.5 * cos(angle), y: 10 + 7.5 * sin(angle))
                            let dot = Path(ellipseIn: CGRect(x: center.x - 0.65, y: center.y - 0.65, width: 1.3, height: 1.3))
                            context.fill(dot, with: .color(ink.opacity(index < filled ? 1 : 0.22)))
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
