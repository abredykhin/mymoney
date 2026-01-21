//
//  CategoryRowView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

struct CategoryRowView: View {
    let category: SpendingCategory
    let period: BudgetPeriod
    
    var body: some View {
        HStack {
            Text(category.name)
                .font(Typography.body)
            Spacer()
            Text(category.amount, format: .currency(code: "USD"))
                .font(Typography.mono)
            Text("per \(period.shortName)")
                .font(Typography.caption)
                .foregroundColor(ColorPalette.textSecondary)
        }
    }
}

#Preview {
    CategoryRowView(
        category: .init(name: "Eating out", amount: 300.0),
        period: .weekly
    )
}
