    //
    //  TransactionListView.swift
    //  UxComponents
    //
    //  Created by Anton Bredykhin on 10/12/24.
    //

import SwiftUI

struct TransactionListView: View {
    @State var transactionList: [Transaction]
    var body: some View {
        List {
            Section(header: Text("Transactions")
                .font(.title3)
                ) {
                    
                    ForEach(transactionList, id: \.id) { transaction in
                        TransactionView(transaction: transaction)
                    }
                    
                }
        }
    }
}

#Preview {
    let transactionList: [Transaction] = [
        MockTransactions.transaction1,
        MockTransactions.transaction2,
        MockTransactions.transaction3
    ]
    
    TransactionListView(transactionList: transactionList)
}
