//
//  BankDetailView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/1/24.
//

import SwiftUI

struct BankDetailView : View {
    @State var bank: Bank
    @EnvironmentObject var bankAccountsService: BankAccountsService
    
    var body: some View {
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
                
                    // Cached indicator if using cached data
                if bankAccountsService.isUsingCachedData {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.secondary)
                        Text("Cached")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
                // Rest of your existing code...
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct BankDetailView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static let bank = Bank(id: 0, bank_name: "A Bank", accounts: [account])
    static var previews: some View {
        BankView(bank: bank)
    }
}
