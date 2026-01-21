//
//  TotalBalanceView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 10/13/24.
//

import SwiftUI

struct TotalBalanceView: View {
    @StateObject var budgetService = BudgetService()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Total Balance")
                    .font(Typography.body)
                    .foregroundColor(ColorPalette.textPrimary)
                    .lineLimit(1)
                
                if let totalBalance = budgetService.totalBalance {
                    Text(totalBalance.balance, format: .currency(code: totalBalance.iso_currency_code))
                        .font(Typography.h4)
                        .monospaced()
                }
            }
            .padding(Spacing.lg)
            
            Spacer()
        }
        .card()
        .onAppear() {
            Task {
                try? await budgetService.fetchTotalBalance()
            }
        }
    }
}

#Preview {
    TotalBalanceView()
}
