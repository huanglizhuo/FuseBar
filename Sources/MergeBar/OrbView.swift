import SwiftUI

/// Single geometry shared by the actual status item, onboarding and the fixture gallery.
struct OrbView: View {
    let snapshot: StatusSnapshot
    var preferences = IndicatorPreferences()

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 22
            context.scaleBy(x: scale, y: scale)
            let ink = GraphicsContext.Shading.color(.primary)
            func line(_ a: CGPoint, _ b: CGPoint, width: CGFloat = 1.2) {
                var path = Path(); path.move(to: a); path.addLine(to: b)
                context.stroke(path, with: ink, style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat) {
                context.draw(Text(value).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(.primary), at: CGPoint(x: x, y: y))
            }
            func arc(_ fraction: Double, opacity: Double, dashed: Bool = false) {
                var path = Path()
                // 300° usable battery sweep; the lower gap is reserved for Bluetooth.
                path.addArc(center: CGPoint(x: 11, y: 10), radius: 7.5,
                            startAngle: .degrees(120), endAngle: .degrees(120 + 300 * fraction), clockwise: false)
                context.stroke(path, with: .color(.primary.opacity(opacity)),
                               style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: dashed ? [1, 2] : []))
            }
            if preferences.battery {
                switch snapshot.battery.availability {
                case .available:
                    arc(1, opacity: 0.18)
                    if snapshot.battery.fraction > 0 { arc(snapshot.battery.fraction, opacity: 1) }
                case .unknown: arc(1, opacity: 0.55, dashed: true)
                case .unavailable: break
                }
            }
            if preferences.wifi {
                switch snapshot.wifi.connection {
                case .connected:
                    for (radius, strength) in [(CGFloat(5.1), 3), (CGFloat(3.1), 2)] {
                        var path = Path()
                        path.addArc(center: CGPoint(x: 11, y: 12), radius: radius,
                                    startAngle: .degrees(222), endAngle: .degrees(318), clockwise: false)
                        let visible = snapshot.wifi.bars == 0 || snapshot.wifi.bars >= strength
                        context.stroke(path, with: .color(.primary.opacity(visible ? 1 : 0.2)),
                                       style: StrokeStyle(lineWidth: 1.15, lineCap: .round))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: 10.2, y: 11.3, width: 1.6, height: 1.6)), with: ink)
                case .disconnected:
                    line(CGPoint(x: 8.8, y: 8), CGPoint(x: 13.2, y: 12.4))
                    line(CGPoint(x: 13.2, y: 8), CGPoint(x: 8.8, y: 12.4))
                case .off: line(CGPoint(x: 8.5, y: 10), CGPoint(x: 13.5, y: 10))
                case .unknown, .unavailable: text("?", x: 11, y: 10, size: 8)
                }
            }
            if preferences.bluetooth {
                let dot = Path(ellipseIn: CGRect(x: 10, y: 17, width: 2, height: 2))
                switch snapshot.bluetooth.state {
                case .on:
                    if snapshot.bluetooth.devices.isEmpty { context.stroke(dot, with: ink, lineWidth: 0.7) }
                    else { context.fill(dot, with: ink) }
                case .off, .unavailable: break
                default: text("?", x: 11, y: 18, size: 4.5)
                }
            }
            switch snapshot.badge(preferences) {
            case .critical: text("!", x: 20, y: 4, size: 7)
            case .charging:
                var bolt = Path()
                bolt.move(to: CGPoint(x: 21, y: 0.6)); bolt.addLine(to: CGPoint(x: 18.5, y: 4))
                bolt.addLine(to: CGPoint(x: 20.1, y: 4)); bolt.addLine(to: CGPoint(x: 18.8, y: 7.2))
                context.stroke(bolt, with: ink, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            case .none: break
            }
            if preferences.sound && snapshot.sound.effectivelyMuted {
                line(CGPoint(x: 18.3, y: 16), CGPoint(x: 21, y: 18.7), width: 1)
                line(CGPoint(x: 21, y: 16), CGPoint(x: 18.3, y: 18.7), width: 1)
            }
            if !preferences.wifi && (!preferences.battery || snapshot.battery.availability == .unavailable) {
                // A stable neutral anchor keeps the app reachable even when all indicators are off.
                context.stroke(Path(ellipseIn: CGRect(x: 7, y: 6, width: 8, height: 8)), with: ink, lineWidth: 1.2)
            }
        }
        .accessibilityLabel(snapshot.accessibilitySummary(preferences))
    }
}
