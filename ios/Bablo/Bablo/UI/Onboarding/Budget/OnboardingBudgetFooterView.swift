//
//  OnboardingBudgetFooterView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

// Footer Component
struct OnboardingBudgetFooterView: View {
    var body: some View {
        Text("These numbers will be automatically updated as you use the app")
            .font(Typography.footnote)
            .foregroundColor(ColorPalette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, Spacing.lg)
    }
}
