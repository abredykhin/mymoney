    //
    //  BankAccountView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 9/2/24.
    //

import SwiftUI
import Foundation

struct BankListView: View {
    @EnvironmentObject var bankAccountsService: BankAccountsService
    
        // Date formatter properly defined
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack {
            Text("Accounts")
                .font(.headline)
                .padding(.leading)
            
            if bankAccountsService.isLoading {
                ProgressView("Loading accounts...")
                    .padding()
            } else if bankAccountsService.banksWithAccounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No accounts found")
                        .foregroundColor(.secondary)
                    LinkButtonView()
                        .padding(.top)
                }
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(bankAccountsService.banksWithAccounts, id: \.id) { bank in
                            BankView(bank: bank)
                                .padding(.bottom, 4)
                        }
                    }
                    
                    if let lastUpdated = bankAccountsService.lastUpdated {
                        Text("Last updated: \(dateFormatter.string(from: lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                }
            }
        }
        .refreshable {
            try? await bankAccountsService.refreshAccounts(forceRefresh: true)
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
