//
//  BankDetailView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/1/24.
//

import SwiftUI

struct BankDetailView : View {
    @State var bank: Bank
    @EnvironmentObject var accountsService: AccountsService
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                if let logo = bank.decodedLogo {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .padding(.trailing, Spacing.xs)
                }
                
                Text(bank.bank_name)
                    .font(Typography.h4)
                    .foregroundColor(ColorPalette.textPrimary)
                    .lineLimit(2)
                
                Spacer()
            }
            
            BankView(bank: bank)
        }
        .padding(Spacing.md)
        .card()
        .padding(.horizontal, Spacing.lg)
    }
}

struct BankDetailView_Previews: PreviewProvider {
    static let account = BankAccount(
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
    static let bank = Bank(
        id: 0,
        bank_name: "A Bank",
        logo: nil,
        primary_color: nil,
        url: nil,
        accounts: [account]
    )
    static var previews: some View {
        BankView(bank: bank)
    }
}
