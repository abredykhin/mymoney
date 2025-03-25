//
//  ContentView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/10/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var userAccount: UserAccount
    @StateObject private var transactionsService = TransactionsService()

    var body: some View {
        if (userAccount.isSignedIn) {
            TabView {
                HomeView()
                    .environmentObject(transactionsService)
                    .tabItem {
                        Label("Overview", systemImage: "house.fill")
                    }
                
                AllTransactionsView()
                    .environmentObject(transactionsService)
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet")
                    }
            }
        } else {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
}
