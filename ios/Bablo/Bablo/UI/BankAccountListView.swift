    //
    //  BankAccountView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 9/2/24.
    //

import SwiftUI

struct BankAccountListView: View {
    @EnvironmentObject var bankAccounts: BankAccounts
    
    var body: some View {
        LazyVStack(alignment: .leading) {
            ForEach(bankAccounts.accounts, id: \.id) {account in
                AccountView(account: account)
            }
        }.task {
            try? await bankAccounts.refreshAccounts()
        }
    }
}

struct BankAccountListView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, item_id: 1, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static var previews: some View {
        BankAccountListView()
            //        BankAccountView(account: account)
    }
}
