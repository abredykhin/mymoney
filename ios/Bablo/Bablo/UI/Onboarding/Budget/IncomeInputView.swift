//
//  IncomeInputView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

// Income Input Component
struct IncomeInputView: View {
    @Binding var income: Double
    @Binding var period: BudgetPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income")
                .font(.headline)
            
            HStack {
                CurrencyTextField(title: "Amount", value: $income)
                    .frame(maxWidth: .infinity)
                
                PeriodPickerView(period: $period)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
