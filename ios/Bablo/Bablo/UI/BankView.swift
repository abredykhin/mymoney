//
//  BankView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/22/24.
//

import SwiftUI

struct BankView : View {
    @State var bank: Bank

    var body: some View {
        ScrollView {
            Text(bank.bank_name)
                .font(.largeTitle)
                .padding(.trailing, 4)
                .padding(.bottom, 8)

            LazyVStack {
                ForEach(bank.accounts, id: \.id) {account in
                    BankAccountView(account: account)
                        .padding(.bottom, 4)
                }
            }
        }
    }
}

struct BankView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static let bank = Bank(id: 0, bank_name: "A Bank", accounts: [account])
    static var previews: some View {
        BankView(bank: bank)
    }
}
