import SwiftUI

/// Consistent spacing scale based on 4pt/8pt grid system
enum Spacing {
    // MARK: - Base Scale
    /// 2pt - Micro adjustments, tight spacing
    static let xxs: CGFloat = 2

    /// 4pt - Minimal spacing
    static let xs: CGFloat = 4

    /// 8pt - Small gaps between related items
    static let sm: CGFloat = 8

    /// 10pt - Default spacing between items
    static let md: CGFloat = 10

    /// 14pt - Section spacing, comfortable gaps
    static let lg: CGFloat = 14

    /// 14pt - Large sections, prominent spacing
    static let xl: CGFloat = 14

    /// 24pt - Major sections, clear separation
    static let xxl: CGFloat = 24

    /// 32pt - Hero spacing, maximum separation
    static let xxxl: CGFloat = 32

    // MARK: - Semantic Aliases (Use these for clarity)
    /// Standard padding inside cards - 18pt
    static let cardPadding = xl

    /// Screen edge margins - 14pt
    static let screenEdge = lg

    /// Spacing between list items - 10pt
    static let itemSpacing = md

    /// Spacing between major sections - 18pt
    static let sectionSpacing = xl

    /// Button padding (vertical) - 12pt
    static let buttonVertical = md

    /// Button padding (horizontal) - 24pt
    static let buttonHorizontal = xl
}
