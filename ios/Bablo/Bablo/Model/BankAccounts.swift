    //
    //  AccountsViewModel.swift
    //  mymoney
    //
    //  Created by Anton Bredykhin on 2/19/24.
    //

import Foundation
import SwiftUI
import OpenAPIRuntime
import OpenAPIURLSession

typealias BankAccount = Components.Schemas.Account

@MainActor
class BankAccounts: ObservableObject {    
    @Published var accounts: [BankAccount] = []
    private let userAccount: UserAccount = UserAccount.shared
    private var client: Client? = nil
        
    func refreshAccounts() async throws {
        Logger.d("Refreshing accounts")
        updateClient()
        guard let client = client else {
            Logger.e("Client is not set!")
            return
        }
        
        Logger.d("Querying server for accounts")
        let response = try await client.getUserAccounts()
        
        switch (response) {
        case .ok(let json):
            switch (json.body) {
            case .json(let accounts):
                Logger.i("Received \(accounts.count) accounts from server")
                self.accounts = accounts
            }
        case .unauthorized(_):
            userAccount.signOut()
            throw URLError(.userAuthenticationRequired)
        case .undocumented(_, _):
            Logger.e("Failed to retrieve accounts from server")
            throw URLError(.badURL)
            
        }
    }
    
    private func updateClient() {
        client = userAccount.client.map(\.self)
    }
}
