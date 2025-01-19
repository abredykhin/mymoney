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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                CurrencyTextField(title: "Amount", value: $amount)
                    .frame(maxWidth: .infinity)
                
                Text("per \(period.shortName)")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var previewAmount: Double = 1000
        @State private var previewPeriod: BudgetPeriod = .monthly
        
        var body: some View {
            VStack(spacing: 20) {
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
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewWrapper()
}
