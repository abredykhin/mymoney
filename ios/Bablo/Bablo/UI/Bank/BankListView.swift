    //
    //  BankAccountView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 9/2/24.
    //

import SwiftUI
import Foundation

struct BankListView: View {
    @EnvironmentObject var accountsService: AccountsService
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack {
            if accountsService.isLoading {
                ProgressView("Loading accounts...")
                    .padding()
            } else if accountsService.banksWithAccounts.isEmpty {
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
                if let lastUpdated = accountsService.lastUpdated {
                    Text("Last updated: \(dateFormatter.string(from: lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(accountsService.banksWithAccounts, id: \.id) { bank in
                            BankView(bank: bank)
                                .padding(.bottom, 4)
                        }
                    }
                    LinkButtonView()
                        .padding()
                }
            }
        }
        .refreshable {
            try? await accountsService.refreshAccounts(forceRefresh: true)
        }
    }
}

struct BankListView_Previews: PreviewProvider {
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
        updated_at: .now
    )
    static let banks = [Bank(id: 0, bank_name: "A Bank", logo: nil, primary_color: nil, url: nil, accounts: [account])]
    static var previews: some View {
        BankListView()
            .environmentObject(AccountsService())
    }
}
