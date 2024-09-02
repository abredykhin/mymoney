//
//  mymoneyApp.swift
//  mymoney
//
//  Created by Anton Bredykhin on 12/17/23.
//

import SwiftUI

@main
struct mymoneyApp: App {
    @StateObject var userAccount = UserAccount()
    @StateObject var bankAccountManager = BankAccountsManager()
    @State var theme = Theme.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userAccount)
                .environmentObject(bankAccountManager)
                .task {
                    userAccount.checkCurrentUser()
                }
        }
        .onChange(of: userAccount.currentUser) {
            bankAccountManager.client = userAccount.client
        }
    }
}
