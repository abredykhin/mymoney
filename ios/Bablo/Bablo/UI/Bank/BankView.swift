//
//  BankView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/22/24.
//

import SwiftUI

struct BankView : View {
    let bank: Bank  // Changed from @State to let - this is a read-only view

    private var backgroundColor: Color {
        Color(hex: bank.primary_color) ?? Color.white
    }
    
    var body: some View {
        NavigationLink(value: bank) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    if let logo = bank.decodedLogo {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .padding(.trailing, Spacing.xs)
                    }
                    
                    Text(bank.bank_name)
                        .font(Typography.mono)
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                }
                
                VStack {
                    ForEach(bank.accounts.filter { $0.hidden != true }, id: \.id) { account in
                        NavigationLink(value: account) {
                            BankAccountView(account: account)
//                                .background(backgroundColor)
                        }
                    }
                }.padding(.leading, Spacing.xs)
            }.padding(Spacing.md)
            .card()
        }
    }
}

struct BankView_Previews: PreviewProvider {
    static let account1 = BankAccount(
        id: 0,
        item_id: 1,
        name: "Account",
        mask: "1234",
        official_name: "Checking Account",
        current_balance: 100.0,
        available_balance: 95.0,
        _type: "checking",
        subtype: nil,
        hidden: false,
        iso_currency_code: "USD",
        updated_at: Date.now
    )

    static let account2 = BankAccount(
        id: 1,
        item_id: 1,
        name: "Account",
        mask: "5678",
        official_name: "Credit Card",
        current_balance: 300.0,
        available_balance: 300.0,
        _type: "credit",
        subtype: "credit_card",
        hidden: false,
        iso_currency_code: "USD",
        updated_at: Date.now
    )

    static let bank = Bank(
        id: 0,
        bank_name: "A Bank",
        logo: nil,
        primary_color: "#00FFBB",
        url: nil,
        accounts: [account1, account2]
    )

    static var previews: some View {
        BankView(bank: bank)
    }
}
