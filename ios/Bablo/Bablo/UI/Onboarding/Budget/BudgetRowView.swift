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
                .frame(width: Spacing.sm, height: Spacing.sm)
            Text(title)
                .font(Typography.body)
            Spacer()
            VStack(alignment: .trailing) {
                Text(amount, format: .currency(code: "USD"))
                    .font(Typography.bodyMedium)
                Text("per \(period.shortName)")
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
    }
}

#Preview {
    BudgetRowView(
        title: "Salary",
        amount: 300.0,
        period: .biweekly,
        color: ColorPalette.success
    )
}
