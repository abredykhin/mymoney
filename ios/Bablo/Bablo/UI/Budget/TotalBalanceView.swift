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
        VStack(alignment: .leading) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.bottom)
            
            if let totalBalance = budgetService.totalBalance {
                Text(totalBalance.balance, format: .currency(code: totalBalance.iso_currency_code))
                    .font(.largeTitle.bold())
            }
        }
        .padding()
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
