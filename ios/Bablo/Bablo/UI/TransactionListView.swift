//
//  TransactionListView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/25/24.
//

import SwiftUI

struct TransactionListView : View {
    @State var account: BankAccount
    @StateObject var transactionsService = TransactionsService()
    
    var body: some View {
        ScrollView {
            VStack {
                Text("Transactions")
                    .font(.largeTitle)
                    .padding(.bottom, 12)
                
                LazyVStack {
                    ForEach(transactionsService.transactions, id: \.id) { transaction in
                        TransactionView(transaction: transaction)
                    }
                }
            }
        }
        .task {
            try? await transactionsService.fetchAccountTransactions(String(account.id))
        }
    }
}

