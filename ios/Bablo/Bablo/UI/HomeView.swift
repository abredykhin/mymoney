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
                VStack(alignment: .leading) {
                    TotalBalanceView()
                    BankListView()
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Home")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
            }
        }
    }
}
