//
//  BudgetRowView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

struct BudgetRowView: View {
    let title: String
    let amount: Double
    let period: BudgetPeriod
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
            Spacer()
            VStack(alignment: .trailing) {
                Text(amount, format: .currency(code: "USD"))
                    .fontWeight(.medium)
                Text("per \(period.shortName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    BudgetRowView(
        title: "Salary",
        amount: 300.0,
        period: .biweekly,
        color: .green
    )
}
