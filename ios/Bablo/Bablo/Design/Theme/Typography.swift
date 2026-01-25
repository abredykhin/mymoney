import SwiftUI

/// Centralized typography system with consistent type scale
struct Typography {
    // MARK: - Display Styles (Hero content, large numbers)
    /// Very large display - 80pt, bold, rounded (e.g., welcome icon)
    static let displayLarge = Font.system(size: 80, weight: .bold, design: .rounded)

    /// Medium display - 44pt, bold, rounded (e.g., onboarding headers)
    static let displayMedium = Font.system(size: 44, weight: .bold, design: .rounded)

    /// Small display - 28pt, bold, rounded (e.g., hero card amounts)
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded)

    // MARK: - Headings
    /// H1 - 32pt, bold, rounded
    static let h1 = Font.system(size: 32, weight: .bold, design: .rounded)

    /// H2 - 28pt, bold, rounded
    static let h2 = Font.system(size: 28, weight: .bold, design: .rounded)

    /// H3 - 24pt, bold, rounded
    static let h3 = Font.system(size: 24, weight: .bold, design: .rounded)

    /// H4 - 20pt, semibold
    static let h4 = Font.system(size: 20, weight: .semibold)

    // MARK: - Body Text
    /// Large body - 17pt (iOS default for readability)
    static let bodyLarge = Font.system(size: 17, weight: .regular)

    /// Standard body - 16pt
    static let body = Font.system(size: 16, weight: .regular)

    /// Medium weight body - 16pt
    static let bodyMedium = Font.system(size: 16, weight: .medium)

    /// Semibold body - 16pt
    static let bodySemibold = Font.system(size: 16, weight: .semibold)

    // MARK: - Small Text
    /// Caption - 14pt
    static let caption = Font.system(size: 14, weight: .regular)

    /// Caption medium - 14pt, medium weight
    static let captionMedium = Font.system(size: 14, weight: .medium)

    /// Caption bold - 14pt, bold
    static let captionBold = Font.system(size: 14, weight: .bold)

    /// Footnote - 12pt
    static let footnote = Font.system(size: 12, weight: .regular)

    // MARK: - Monospaced (Financial Data)
    /// Large monospaced - 17pt (for prominent amounts)
    static let monoLarge = Font.system(size: 17, weight: .regular).monospaced()

    /// Standard monospaced - 16pt
    static let mono = Font.system(size: 16, weight: .regular).monospaced()

    /// Medium weight monospaced - 16pt
    static let monoMedium = Font.system(size: 16, weight: .medium).monospaced()

    /// Small monospaced - 14pt
    static let monoSmall = Font.system(size: 14, weight: .regular).monospaced()

    // MARK: - Semantic Styles (Use case specific)
    /// Amount display in hero cards
    static let amountDisplay = displaySmall.monospaced()

    /// Card titles/labels
    static let cardTitle = caption

    /// Button labels
    static let buttonLabel = bodyMedium

    /// Transaction amounts
    static let transactionAmount = mono

    /// Transaction details
    static let transactionDetail = monoSmall
}
