//
//  BankListTabView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 4/6/25.
//

import SwiftUI

struct BankListTabView: View {
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var navigationState: NavigationState

    @State private var showingProfile = false

    var body: some View {
        ZStack {
            BankListView()
                .environmentObject(accountsService)
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingProfile = true
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView { ProfileView() }
        }
        .navigationDestination(for: Bank.self) { bank in
            BankDetailView(bank: bank)
        }
        .navigationDestination(for: BankAccount.self) { account in
            BankAccountDetailView(account: account)
        }
    }
}
