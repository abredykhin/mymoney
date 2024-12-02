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
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .padding(.trailing, 8)
                    }
                    
                    Text(bank.bank_name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                }
                .padding(.bottom, 8)
                
                Text("\(bank.accounts.count) Accounts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                ForEach(bank.accounts, id: \.id) {account in
                    NavigationLink(destination: TransactionListView(account: account)) {
                        BankAccountView(account: account)
                    }
                }
            }
            .padding()
            .background(Color.white) // Main card background
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4) // Subtle shadow for the card
            .padding(.horizontal)
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
