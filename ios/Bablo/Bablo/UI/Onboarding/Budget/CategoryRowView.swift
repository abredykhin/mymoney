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
            Spacer()
            Text(category.amount, format: .currency(code: "USD"))
            Text("per \(period.shortName)")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CategoryRowView(
        category: .init(name: "Eating out", amount: 300.0),
        period: .weekly
    )
}
