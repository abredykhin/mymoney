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
        NavigationLink(destination: BankDetailView(bank: bank)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let logo = bank.decodedLogo {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .padding(.trailing, 4)
                    }
                    
                    Text(bank.bank_name)
                        .font(.body.monospaced())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                }
                
                VStack {
                    ForEach(bank.accounts, id: \.id) {account in
                        NavigationLink(destination: TransactionListView(account: account)) {
                            BankAccountView(account: account)
                        }
                    }
                }.padding(.leading, 4)
            }.padding()
            .cardBackground()
        }
    }
}

struct BankView_Previews: PreviewProvider {
    static let account1 = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static let account2 = BankAccount(id: 0, name: "Account", current_balance: 300.0, iso_currency_code: "USD", _type: "credit", updated_at: .now)

    static let bank = Bank(id: 0, bank_name: "A Bank", accounts: [account1, account2])
    static var previews: some View {
        BankView(bank: bank)
    }
}
