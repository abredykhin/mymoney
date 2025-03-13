    //
    //  BankAccountView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 9/2/24.
    //

import SwiftUI

struct BankListView: View {
    @EnvironmentObject var bankAccountsService: BankAccountsService
    @State private var isExpanded: Bool = true

    var body: some View {
        ScrollView {
            VStack {
                Text("Accounts")
                    .font(.headline)
                    .padding(.leading)
                
                LazyVStack(alignment: .leading) {
                    ForEach(bankAccountsService.banksWithAccounts, id: \.id) { bank in
                        BankView(bank: bank)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
    }
}

struct BankListView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static let banks = [Bank(id: 0, bank_name: "A Bank", accounts: [account])]
    static var previews: some View {
        BankListView()
            .environmentObject(BankAccountsService())
    }
}
