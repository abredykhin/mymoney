//
//  RecentTransactionsView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 10/13/24.
//

import SwiftUI

struct RecentTransactionsView: View {
    @EnvironmentObject private var transactionsService: TransactionsService

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Recent Transactions")
                .font(Typography.footnote)
                .foregroundColor(ColorPalette.textSecondary)

            if transactionsService.transactions.isEmpty && !transactionsService.isLoading {
                Text("No transactions")
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.vertical, Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(transactionsService.transactions.prefix(10) , id: \.id) { transaction in
                        TransactionView(transaction: transaction)
                    }
                }
            }
        }
        .glassCard()
        .onAppear() {
            Task {
                try? await transactionsService.fetchRecentTransactions(forceRefresh: false, loadMore: false, limit: 10)
            }
        }
    }
}

#Preview {
    let service: TransactionsService = {
        let s = TransactionsService()
        s.transactions = [
            TransactionView_Previews.foodTransaction,
            TransactionView_Previews.travelTransaction,
            TransactionView_Previews.incomeTransaction
        ]
        s.isLoading = false
        return s
    }()
    
    ZStack {
        ColorPalette.backgroundPrimary.ignoresSafeArea()
        RecentTransactionsView()
            .environmentObject(service)
            .padding()
    }
}
