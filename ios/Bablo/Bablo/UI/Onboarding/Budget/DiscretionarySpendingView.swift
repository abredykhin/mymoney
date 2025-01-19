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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Want to spend")
                    .font(.headline)
                Spacer()
                Toggle("Use Categories", isOn: $isUsingCategories)
            }
            
            if !isUsingCategories {
                HStack {
                    CurrencyTextField(title: "Amount", value: $amount)
                        .frame(maxWidth: .infinity)
                    
                    Text("per \(period.shortName)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
