import SwiftUI

/// Standard card style - solid background with shadow
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ColorPalette.backgroundPrimary)
            .cornerRadius(CornerRadius.card)
            .shadow(Elevation.level2)
            .padding(Spacing.sm)
    }
}

extension View {
    /// Applies standard card styling
    func card() -> some View {
        modifier(CardModifier())
    }
}
