import SwiftUI

/// Renders a status symbol name. Bluetooth names are app-defined marks resolved
/// here — SF Symbols ships no Bluetooth glyph, so they use the custom
/// `logo.bluetooth` symbol (MoreSFSymbols, logos/logo.bluetooth.svg) from the
/// asset catalog. `size` and `weight` should mirror the font the surrounding
/// symbols use, so mixed rows keep their metrics.
struct StatusIcon: View {
    let name: String
    var size: CGFloat?
    var weight: Font.Weight = .regular
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 16

    var body: some View {
        if name == StatusSymbols.bluetooth || name == StatusSymbols.bluetoothOff {
            ZStack {
                Image("logo.bluetooth")
                    .font(.system(size: side, weight: weight))
                if name == StatusSymbols.bluetoothOff { SlashMark().fill() }
            }
            .accessibilityHidden(true)
        } else {
            Image(systemName: name)
        }
    }

    private var side: CGFloat { size ?? scaledSize }
}

/// The Bluetooth logo ships with no slashed variant; the strike-through matches
/// the system slash orientation (top-left to bottom-right).
private struct SlashMark: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0 else { return Path() }
        var line = Path()
        line.move(to: CGPoint(x: rect.minX, y: rect.minY))
        line.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return line.strokedPath(StrokeStyle(lineWidth: rect.width * 0.09, lineCap: .round))
    }
}
