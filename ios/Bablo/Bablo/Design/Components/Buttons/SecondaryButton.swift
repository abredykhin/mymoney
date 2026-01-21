import SwiftUI

/// Secondary button style - outlined/bordered, less prominent
struct SecondaryButton: ViewModifier {
    let isDisabled: Bool

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(ColorPalette.primary)
            .padding(.vertical, Spacing.buttonVertical)
            .padding(.horizontal, Spacing.buttonHorizontal)
            .frame(maxWidth: .infinity)
            .background(ColorPalette.primary.opacity(0.1))
            .cornerRadius(CornerRadius.button)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func secondaryButton(isDisabled: Bool = false) -> some View {
        modifier(SecondaryButton(isDisabled: isDisabled))
    }
}
