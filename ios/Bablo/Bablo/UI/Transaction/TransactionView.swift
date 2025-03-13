//
//  TransactionView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/23/24.
//

import SwiftUI

struct TransactionView : View {
    @State var transaction: Transaction
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Text(transaction.merchant_name ?? transaction.name)
                    .font(.callout)
                    .monospaced()
                    .bold()

                Spacer()
                Text(-transaction.amount, format: .currency(code: transaction.iso_currency_code))
                    .font(.callout)
                    .monospaced()
                    .foregroundStyle(getColor())
            }
            HStack(alignment: .top) {
                Text(formatDate(transaction.authorized_date ?? transaction.date))
                    .font(.footnote)
                    .monospaced()
                
                Spacer()
                if (transaction.pending) {
                    Text("Pending")
                        .font(.footnote)
                        .monospaced()
                        .italic()
                }
            }
        }.padding(1)
    }
    
    func getColor() -> Color {
        //switch transaction.x
        return transaction.amount > 0 ? .red : .teal
    }
}

struct TransactionView_Previews: PreviewProvider {
    static let transaction = Transaction(account_id: 0, amount: 12.50, iso_currency_code: "USD", date: "2024-12-01", name: "McDonalds", payment_channel: "online", transaction_id: "", pending: false)

    static var previews: some View {
        TransactionView(transaction: transaction)
    }
}
