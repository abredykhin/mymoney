    //
    //  AccountsViewModel.swift
    //  mymoney
    //
    //  Created by Anton Bredykhin on 2/19/24.
    //

import Foundation
import SwiftUI

@MainActor
class BankAccountsManager: ObservableObject {
    @Published var accounts: [BankAccount] = []
    var client: Client? = nil
    
    func refreshAccounts() async throws {
        Logger.d("Refreshing accounts")
        guard let client = client else {
            Logger.e("Client is not set!")
            return
        }
        
        do {
            self.accounts = try await refreshAccountsInternal(client: client)
        } catch  {
            Logger.e("Unable to refresh accounts: \(error)")
        }
    }
    
    private func refreshAccountsInternal(client: Client) async throws -> [BankAccount] {
        Logger.d("Querying server for accounts")
        let response = try await client.getUserAccounts()
        
        switch (response) {
        case .ok(let json):
            switch (json.body) {
            case .json(let accounts):
                Logger.i("Received \(accounts.count) accounts from server")
                return accounts
            }
        case .undocumented(_, _):
            Logger.e("Failed to retrieve accounts from server")
            throw URLError(.badURL)
            
        }
    }
}
