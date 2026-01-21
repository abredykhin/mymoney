import SwiftUI

/// Primary button style - full color background, prominent CTA
struct PrimaryButton: ViewModifier {
    let isLoading: Bool
    let isDisabled: Bool

    init(isLoading: Bool = false, isDisabled: Bool = false) {
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.buttonLabel)
            .foregroundColor(.white)
            .padding(.vertical, Spacing.buttonVertical)
            .padding(.horizontal, Spacing.buttonHorizontal)
            .frame(maxWidth: .infinity)
            .background(ColorPalette.primary)
            .cornerRadius(CornerRadius.button)
            .opacity(isLoading || isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func primaryButton(isLoading: Bool = false, isDisabled: Bool = false) -> some View {
        modifier(PrimaryButton(isLoading: isLoading, isDisabled: isDisabled))
    }
}
