//
//  HomeView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import Foundation
import SwiftUI

struct HomeView: View {    
    @EnvironmentObject var bankAccountsService: BankAccountsService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TotalBalanceView()
                    Divider()
                    BankListView()
                    Spacer()
                    Divider()
                    Spacer()
                    RecentTransactionsView()
                    Spacer()
                    LinkButtonView()
                        .padding(.top)
                }
            }
            .refreshable {
                try? await bankAccountsService.refreshAccounts()
            }.task {
                try? await bankAccountsService.refreshAccounts()
            }
        }
    }
}
