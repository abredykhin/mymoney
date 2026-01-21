import SwiftUI

// MARK: - Design System View Extensions
// Centralized convenience modifiers for consistent styling

extension View {
    // Note: Button and Card modifiers are defined in their respective files
    // This file is reserved for additional shared modifiers

    /// Applies standard screen edge padding (16pt)
    func screenPadding() -> some View {
        self.padding(.horizontal, Spacing.screenEdge)
    }

    /// Applies section spacing (24pt bottom padding)
    func sectionSpacing() -> some View {
        self.padding(.bottom, Spacing.sectionSpacing)
    }
}


