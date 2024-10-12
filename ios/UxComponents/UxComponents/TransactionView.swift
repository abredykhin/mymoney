//
//  TransactionView.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

import SwiftUI

struct TransactionView: View {
    @State var transaction: Transaction
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Text(transaction.merchant_name ?? transaction.name)
                    .font(.title3)
                    .bold()
                
                Spacer()
                Text(-transaction.amount, format: .currency(code: transaction.iso_currency_code))
                    .font(.title3)
                    .foregroundStyle( transaction.amount > 0 ? .teal : .red )
                
                
            }
            HStack(alignment: .top) {
                Text(formatDate(transaction.authorized_date ?? transaction.date))
                    .font(.body)
                
                Spacer()
                if (transaction.pending) {
                    Text("Pending")
                        .font(.body)
                        .italic()
                }
            }
        }
        .padding(8)
    }
}

struct TransactionView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            TransactionView(transaction: MockTransactions.transaction1)
            TransactionView(transaction: MockTransactions.transaction2)
        }
    }
}

