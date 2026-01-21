//
//  ExpenseSection.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

struct ExpenseSection: View {
    let title: String
    @Binding var amount: Double
    @Binding var period: BudgetPeriod
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.h4)
                Text(description)
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            HStack {
                CurrencyTextField(title: "Amount", value: $amount)
                    .frame(maxWidth: .infinity)
                
                Text("per \(period.shortName)")
                    .font(Typography.body)
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(Spacing.lg)
        .background(ColorPalette.backgroundPrimary)
        .cornerRadius(CornerRadius.md)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var previewAmount: Double = 1000
        @State private var previewPeriod: BudgetPeriod = .monthly
        
        var body: some View {
            VStack(spacing: Spacing.xl) {
                    // Preview with monthly period
                ExpenseSection(
                    title: "Need to spend",
                    amount: $previewAmount,
                    period: $previewPeriod,
                    description: "Regular bills and essential expenses"
                )
                
                    // Preview with weekly period
                ExpenseSection(
                    title: "Want to save",
                    amount: $previewAmount,
                    period: .constant(.weekly),
                    description: "Your savings goal"
                )
            }
            .padding(Spacing.lg)
            .background(ColorPalette.backgroundSecondary)
        }
    }
    
    return PreviewWrapper()
}
