//
//  AccountsView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import SwiftUI

struct BankAccountsView: View {
    @EnvironmentObject var bankAccountsManager: BankAccountsManager
        
    var body: some View {
        ScrollView {
            LinkButtonView()
             .padding(.top)
            LazyVStack(alignment: .leading) {
                ForEach(bankAccountsManager.accounts) { account in
                    BankAccountView(account: account)
                }
            }
        }.task {
            try? await bankAccountsManager.refreshAccounts()
        }
    }
}

struct BankAccountView: View {
    @State var account: BankAccount
    
    var body: some View {
        HStack(alignment: .center) {
            Text(account.name)
                .font(.title)
                .padding(.trailing, 4)
            Text(account.current_balance, format: .currency(code: account.iso_currency_code))
                .font(.title3)
        }
        .padding(.bottom, 2)
    }
}

struct BankAccountView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, item_id: 1, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static var previews: some View {
        BankAccountView(account: account)

    }
}
