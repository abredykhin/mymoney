//
//  RecentTransactionsView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 10/13/24.
//

import SwiftUI

struct RecentTransactionsView: View {
    @StateObject var transactionsService = TransactionsService()
    
    var body: some View {
        VStack {
            Text("Recent Transactions")
                .font(.headline.monospaced().weight(.semibold))
                .padding(.horizontal)
                .padding(.top, 2)
            
            ForEach(transactionsService.transactions, id: \.id) { transaction in
                TransactionView(transaction: transaction)
                    .padding(.horizontal)
            }
        }
        .cardBackground()
        .onAppear() {
            Task {
                try? await transactionsService.fetchRecentTransactions()
            }
        }
    }
}
