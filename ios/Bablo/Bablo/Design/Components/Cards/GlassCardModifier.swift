import SwiftUI

/// Glassmorphic hero card style - translucent with blur effect
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Dimensions.heroCardHeight, alignment: .leading)
            .background {
                RoundedRectangle(
                    cornerRadius: CornerRadius.heroCard,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: CornerRadius.heroCard,
                        style: .continuous
                    )
                    .stroke(ColorPalette.glassStroke, lineWidth: 1)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
    }
}

extension View {
    /// Applies glassmorphic card styling (for hero cards)
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
