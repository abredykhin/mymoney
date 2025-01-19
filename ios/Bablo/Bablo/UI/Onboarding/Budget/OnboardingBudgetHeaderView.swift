//
//  OnboardingBudgetHeaderView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

// Header Component
struct OnboardingBudgetHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Let's set up your budget basics")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Don't worry about being exact – you can refine these numbers once you link your accounts, and update them anytime.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom)
    }
}
