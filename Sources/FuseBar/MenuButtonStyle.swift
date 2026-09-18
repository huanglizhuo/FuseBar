import SwiftUI

/// Native semantic colors, with a shared hover/pressed/selected treatment.
struct MenuButtonStyle: ButtonStyle {
    var selected = false
    var inset: CGFloat = 0
    func makeBody(configuration: Configuration) -> some View {
        MenuButtonBody(configuration: configuration, selected: selected, inset: inset)
    }
}

private struct MenuButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let selected: Bool
    let inset: CGFloat
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    var body: some View {
        configuration.label.padding(inset)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(configuration.isPressed ? 0.12 : hovered && enabled ? 0.06 : 0))
            }
            .overlay {
                if selected || focused { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1) }
            }
            .opacity(enabled ? 1 : 0.45)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: hovered)
    }
}
