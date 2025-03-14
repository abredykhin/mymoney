//
//  TransactionsService.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/25/24.
//

import Foundation
import SwiftUI
import OpenAPIRuntime
import OpenAPIURLSession

@MainActor
class TransactionsService: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var isUsingCachedData: Bool = false
    @Published var lastUpdated: Date?
    
    private let transactionsManager = TransactionsManager()
    
    func fetchAccountTransactions(_ accountId: String, forceRefresh: Bool = false) async throws {
            // If not forcing refresh and we have recently updated data, return
        if !forceRefresh, !transactions.isEmpty, let lastUpdate = lastUpdated,
            Date().timeIntervalSince(lastUpdate) < 300 {
            Logger.i("Using cached transactions data, last updated: \(lastUpdate)")
            isUsingCachedData = true
            return
        }
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        if !forceRefresh {
                // Try loading from cache first
            let cachedTransactions = transactionsManager.fetchTransactions(for: Int(accountId) ?? 0)
            if !cachedTransactions.isEmpty {
                self.transactions = cachedTransactions
                self.isUsingCachedData = true
                self.isLoading = false
                Logger.i("Loaded \(cachedTransactions.count) transactions from cache")
                return
            }
        }
        
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
            isLoading = false
            return
        }
        
        Logger.d("Fetching transactions from server for account \(accountId)")
        
        do {
            let response = try await client.getAccountTransactions(query: .init(accountId: accountId))
            switch (response) {
            case .ok(let json):
                switch(json.body) {
                case .json(let bodyJson):
                    Logger.i("Successfully fetched \(bodyJson.transactions?.count ?? 0) transactions")
                    if let fetchedTransactions = bodyJson.transactions {
                        self.transactions = fetchedTransactions
                        self.isUsingCachedData = false
                        self.lastUpdated = Date()
                        
                            // Save to CoreData cache
                        if let accountIdInt = Int(accountId) {
                            transactionsManager.saveTransactions(fetchedTransactions, for: accountIdInt)
                        }
                    }
                }
            case .unauthorized(_):
                Logger.w("Unauthorized user. Logging out")
                UserAccount.shared.signOut()
            default:
                Logger.w("Can't handle the response.")
            }
        } catch let error {
            Logger.e("Failed to fetch transactions: \(error)")
            throw error
        }
    }
    
    func fetchRecentTransactions(forceRefresh: Bool = false) async throws {
            // Similar pattern as above but for recent transactions
        if !forceRefresh, !transactions.isEmpty, let lastUpdate = lastUpdated,
            Date().timeIntervalSince(lastUpdate) < 300 {
            Logger.i("Using cached recent transactions, last updated: \(lastUpdate)")
            isUsingCachedData = true
            return
        }
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        if !forceRefresh {
                // Try loading from cache first
            let cachedTransactions = transactionsManager.fetchRecentTransactions()
            if !cachedTransactions.isEmpty {
                self.transactions = cachedTransactions
                self.isUsingCachedData = true
                self.isLoading = false
                Logger.i("Loaded \(cachedTransactions.count) recent transactions from cache")
                return
            }
        }
        
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
            isLoading = false
            return
        }
        
        Logger.d("Fetching recent transactions from server")
        
        do {
            let response = try await client.getRecentTransactions()
            switch (response) {
            case .ok(let json):
                switch(json.body) {
                case .json(let bodyJson):
                    Logger.i("Successfully fetched \(bodyJson.transactions?.count ?? 0) transactions")
                    if let fetchedTransactions = bodyJson.transactions {
                        self.transactions = fetchedTransactions
                        self.isUsingCachedData = false
                        self.lastUpdated = Date()
                        
                            // For each transaction, save to its respective account
                            // Group transactions by account_id
                        let transactionsByAccountId = Dictionary(grouping: fetchedTransactions) { $0.account_id }
                        
                            // Save each group
                        for (accountId, transactions) in transactionsByAccountId {
                            transactionsManager
                                .saveTransactions(
                                    transactions,
                                    for: Int(accountId)
                                )
                        }
                    }
                }
            case .unauthorized(_):
                Logger.w("Unauthorized user. Logging out")
                UserAccount.shared.signOut()
            default:
                Logger.w("Can't handle the response.")
            }
        } catch let error {
            Logger.e("Failed to fetch recent transactions: \(error)")
            throw error
        }
    }
}
