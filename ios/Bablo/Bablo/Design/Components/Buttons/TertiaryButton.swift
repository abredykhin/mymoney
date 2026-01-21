import SwiftUI

/// Tertiary button style - text only, minimal
struct TertiaryButton: ViewModifier {
    let isDisabled: Bool

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(ColorPalette.primary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func tertiaryButton(isDisabled: Bool = false) -> some View {
        modifier(TertiaryButton(isDisabled: isDisabled))
    }
}
