import SwiftUI

/// Consistent corner radius values for UI elements
enum CornerRadius {
    /// 4pt - Minimal rounding
    static let xs: CGFloat = 4

    /// 8pt - Small elements, text fields
    static let sm: CGFloat = 8

    /// 12pt - Medium elements
    static let md: CGFloat = 12

    /// 16pt - Standard cards
    static let lg: CGFloat = 16

    /// 24pt - Hero cards, prominent elements
    static let xl: CGFloat = 24

    /// 100pt - Fully rounded (pills, buttons)
    static let pill: CGFloat = 100

    // MARK: - Semantic Aliases
    /// Standard card corner radius - 16pt
    static let card = lg

    /// Hero card corner radius - 24pt
    static let heroCard = xl

    /// Button corner radius - 100pt (pill shape)
    static let button = pill

    /// Text field corner radius - 8pt
    static let textField = sm
}
