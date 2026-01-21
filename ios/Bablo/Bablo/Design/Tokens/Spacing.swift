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

    /// 12pt - Default spacing between items
    static let md: CGFloat = 12

    /// 16pt - Section spacing, comfortable gaps
    static let lg: CGFloat = 16

    /// 24pt - Large sections, prominent spacing
    static let xl: CGFloat = 24

    /// 32pt - Major sections, clear separation
    static let xxl: CGFloat = 32

    /// 40pt - Hero spacing, maximum separation
    static let xxxl: CGFloat = 40

    // MARK: - Semantic Aliases (Use these for clarity)
    /// Standard padding inside cards - 24pt
    static let cardPadding = xl

    /// Screen edge margins - 16pt
    static let screenEdge = lg

    /// Spacing between list items - 12pt
    static let itemSpacing = md

    /// Spacing between major sections - 24pt
    static let sectionSpacing = xl

    /// Button padding (vertical) - 12pt
    static let buttonVertical = md

    /// Button padding (horizontal) - 24pt
    static let buttonHorizontal = xl
}
