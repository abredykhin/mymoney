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

typealias Bank = Components.Schemas.Bank
typealias BankAccount = Components.Schemas.Account

@MainActor
class BankAccountsService: ObservableObject {
    @Published var bankAccounts: [Bank] = []
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
        do {
            let response = try await client.getUserAccounts()
            
            switch (response) {
            case .ok(let json):
                switch (json.body) {
                case .json(let bodyJson):
                    Logger.i("Received \(bodyJson.banks?.count ?? 0) banks from server")
                    self.bankAccounts = bodyJson.banks ?? []
                }
            case .unauthorized(_):
                userAccount.signOut()
                throw URLError(.userAuthenticationRequired)
            case .undocumented(_, _):
                Logger.e("Failed to retrieve accounts from server")
                throw URLError(.badURL)
            case .internalServerError(_):
                Logger.e("Failed to retrieve accounts from server")
            }
        } catch let error {
            Logger.e("Failed to refresh accounts: \(error)")
            throw error
        }
    }
    
    private func updateClient() {
        client = userAccount.client.map(\.self)
    }
}
