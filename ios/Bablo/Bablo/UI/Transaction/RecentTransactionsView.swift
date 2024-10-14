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
                // Recent Transactions Section
            Text("Recent Transactions")
                .font(.title)
                .padding(.horizontal)
            
            ForEach(transactionsService.transactions, id: \.id) { transaction in
                TransactionView(transaction: transaction)
                    .padding(.horizontal)
            }
        }.task {
            try? await transactionsService.fetchRecentTransactions()
        }
    }
}
