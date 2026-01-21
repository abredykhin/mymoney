//
//  DiscretionarySpendingView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

struct DiscretionarySpendingView: View {
    @Binding var isUsingCategories: Bool
    @Binding var amount: Double
    let period: BudgetPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Want to spend")
                    .font(Typography.h4)
                Spacer()
                Toggle("Use Categories", isOn: $isUsingCategories)
            }
            
            if !isUsingCategories {
                HStack {
                    CurrencyTextField(title: "Amount", value: $amount)
                        .frame(maxWidth: .infinity)
                    
                    Text("per \(period.shortName)")
                        .font(Typography.body)
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorPalette.backgroundPrimary)
        .cornerRadius(CornerRadius.md)
    }
}
