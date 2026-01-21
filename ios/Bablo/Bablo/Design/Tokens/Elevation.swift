import SwiftUI

/// Shadow configuration for depth/elevation system
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Consistent shadow/elevation system
enum Elevation {
    // MARK: - Standard Elevations
    /// Level 1 - Subtle depth (e.g., floating buttons)
    static let level1 = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 2,
        x: 0,
        y: 1
    )

    /// Level 2 - Cards, standard elevation
    static let level2 = ShadowStyle(
        color: Color.black.opacity(0.15),
        radius: 4,
        x: 0,
        y: 2
    )

    /// Level 3 - Raised cards, modals
    static let level3 = ShadowStyle(
        color: Color.black.opacity(0.2),
        radius: 8,
        x: 0,
        y: 4
    )

    /// Level 4 - Maximum elevation, overlays
    static let level4 = ShadowStyle(
        color: Color.black.opacity(0.25),
        radius: 16,
        x: 0,
        y: 8
    )

    // MARK: - Special Effects
    /// Glassmorphic glow (positive/teal)
    static let glowPositive = ShadowStyle(
        color: ColorPalette.glowPositive.opacity(0.5),
        radius: 20,
        x: 0,
        y: 10
    )

    /// Glassmorphic glow (negative/red)
    static let glowNegative = ShadowStyle(
        color: ColorPalette.glowNegative.opacity(0.5),
        radius: 20,
        x: 0,
        y: 10
    )

    /// Income glow (green)
    static let glowIncome = ShadowStyle(
        color: ColorPalette.glowIncome.opacity(0.3),
        radius: 8,
        x: 0,
        y: 0
    )
}

// MARK: - View Extension for Easy Shadow Application
extension View {
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}
