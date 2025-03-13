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
            VStack(alignment: .leading) {
                Text("Total Balance")
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.bottom, 2)
                    .monospaced()
                
                if let totalBalance = budgetService.totalBalance {
                    Text(totalBalance.balance, format: .currency(code: totalBalance.iso_currency_code))
                        .font(.title3.weight(.medium))
                        .monospaced()
                }
            }.padding()
            Spacer()
        }
        .cardBackground()
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
