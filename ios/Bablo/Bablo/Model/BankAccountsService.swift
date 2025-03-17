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
typealias Transaction = Components.Schemas.Transaction

@MainActor
class BankAccountsService: ObservableObject {
    @Published var banksWithAccounts: [Bank] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    @Published var isUsingCachedData: Bool = false

    private let userAccount: UserAccount = UserAccount.shared
    private var client: Client? = nil
    private let bankManager = BankManager()
    
    init() {
        loadCachedData()
    }
    
    func loadCachedData() {
        let cachedBanks = bankManager.fetchBanks()
        if !cachedBanks.isEmpty {
            self.banksWithAccounts = cachedBanks
            Logger.i("Loaded \(cachedBanks.count) banks from CoreData cache")
        }
    }
    
    func refreshAccounts(forceRefresh: Bool = false) async throws {
            // If not forcing refresh and we have recently updated data, return
        if !forceRefresh, !banksWithAccounts.isEmpty, let lastUpdate = lastUpdated,
            Date().timeIntervalSince(lastUpdate) < 300 {
            Logger.i("Using cached data, last updated: \(lastUpdate)")
            isUsingCachedData = true
            return
        }
        
        isLoading = true
        
        defer {
            isLoading = false
        }
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
                    if let banks = bodyJson.banks {
                        self.banksWithAccounts = banks
                        self.lastUpdated = Date()
                        
                        // Save to CoreData cache
                        bankManager.saveBanks(banks)
                        
                        // Save accounts for each bank
                        let accountManager = AccountManager()
                        for bank in banks {
                            accountManager.saveAccounts(bank.accounts, for: bank.id)
                        }
                        isUsingCachedData = false
                    }
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
    
    func deleteItem(itemId: Int) async throws {
        isLoading = true
        defer { isLoading = false }
        
        updateClient()
        guard let client = client else {
            Logger.e("Client is not set!")
            throw URLError(.badURL)
        }
        
        Logger.d("Deleting item \(itemId) from server")
        do {
            let response = try await client.deleteItem(.init(path: .init(itemId: String(itemId))))
            
            switch response {
            case .noContent:
                // Remove from local cache
                bankManager.removeBank(withId: itemId)
                
                // Remove from published list
                self.banksWithAccounts.removeAll { $0.id == itemId }
                Logger.i("Successfully deleted bank item \(itemId)")
            case .unauthorized(_):
                userAccount.signOut()
                throw URLError(.userAuthenticationRequired)
            case .notFound(_):
                Logger.e("Item not found on server")
                throw URLError(.resourceUnavailable)
            case .undocumented(_, _):
                Logger.e("Failed to delete item from server")
                throw URLError(.badServerResponse)
            }
        } catch {
            Logger.e("Failed to delete item: \(error)")
            throw error
        }
    }
    
    private func updateClient() {
        client = userAccount.client.map(\.self)
    }
}

// Extension on Bank to decode Base64 to UIImage
extension Bank {
    var decodedLogo: UIImage? {
        guard let logoBase64 = self.logo,
              let data = Data(base64Encoded: logoBase64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }
}
