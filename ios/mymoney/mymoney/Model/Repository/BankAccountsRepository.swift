//
//  AccountsRepository.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

typealias BankAccount = Components.Schemas.Account
extension BankAccount : Identifiable {
    
}

class BankAccountsRepository {
    static func refreshAccounts(client: Client) async throws -> [BankAccount] {
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
