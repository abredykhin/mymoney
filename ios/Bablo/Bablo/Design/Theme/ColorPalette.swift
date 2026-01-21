import SwiftUI
import UIKit

/// Centralized color palette for the MyMoney app
/// Uses semantic naming to support light/dark mode and maintain consistency
struct ColorPalette {
    // MARK: - Brand Colors
    /// Primary brand color (teal/green)
    static let primary = Color.accentColor

    /// Secondary brand color
    static let secondary = Color("SecondaryColor")

    // MARK: - Semantic Colors (State-based)
    /// Positive outcomes, income, gains
    static let success = Color.green

    /// Warnings, caution, pending states
    static let warning = Color.orange

    /// Errors, debt, negative outcomes
    static let error = Color.red

    /// Informational, neutral actions
    static let info = Color.blue

    // MARK: - Text Colors (Adaptive)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Background Colors (Adaptive)
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)

    // MARK: - UI Elements
    static let border = Color(UIColor.separator)
    static let divider = Color(UIColor.separator).opacity(0.5)

    // MARK: - Transaction Category Colors
    static let categoryIncome = success
    static let categoryTransferIn = Color.blue
    static let categoryTransferOut = Color.orange
    static let categoryLoanPayments = Color.purple
    static let categoryBankFees = error
    static let categoryFood = Color.pink
    static let categoryEntertainment = Color.indigo
    static let categoryTravel = Color.cyan
    static let categoryDefault = textSecondary

    // MARK: - Glassmorphic Effects
    static let glassFill = Color.white.opacity(0.1)
    static let glassStroke = Color.white.opacity(0.4)

    /// Teal glow for positive financial states
    static let glowPositive = Color(red: 0.4, green: 1.0, blue: 0.8)

    /// Red/orange glow for negative financial states
    static let glowNegative = Color(red: 1.0, green: 0.5, blue: 0.4)

    /// Green glow for income/gains
    static let glowIncome = Color(red: 0.5, green: 1.0, blue: 0.0)
}
