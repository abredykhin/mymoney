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
        Text(account.name)
            .padding()
    }
}
