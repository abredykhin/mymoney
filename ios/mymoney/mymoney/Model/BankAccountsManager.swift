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
            self.accounts = try await BankAccountsRepository.refreshAccounts(client: client)
        } catch  {
            Logger.e("Unable to refresh accounts: \(error)")
        }
    }
}
