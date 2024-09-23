    //
    //  BankAccountView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 9/2/24.
    //

import SwiftUI

struct BankAccountListView: View {
    @EnvironmentObject var bankAccountsService: BankAccountsService
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(bankAccountsService.bankAccounts, id: \.id) { bank in
                    BankView(bank: bank)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

struct BankAccountListView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static let banks = [Bank(id: 0, bank_name: "A Bank", accounts: [account])]
    static var previews: some View {
        BankAccountListView()
            .environmentObject(BankAccountsService())
    }
}
