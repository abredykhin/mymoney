//
//  HomeView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import Foundation
import SwiftUI

struct HomeView: View {
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
