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
        VStack {
            Text("Recent Transactions")
                .font(Typography.mono.weight(.bold))
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xxs)
            
            if transactionsService.transactions.isEmpty && !transactionsService.isLoading {
                Text("No transactions")
                    .font(Typography.bodyMedium)
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(Spacing.md)
            } else {
                ForEach(transactionsService.transactions, id: \.id) { transaction in
                    TransactionView(transaction: transaction)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
        .card()
        .onAppear() {
            Task {
                try? await transactionsService.fetchRecentTransactions(forceRefresh: false, loadMore: false, limit: 10)
            }
        }
    }
}
