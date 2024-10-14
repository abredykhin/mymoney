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

    func fetchAccountTransactions(_ accountId: String) async throws {
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
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
                    self.transactions = bodyJson.transactions ?? []
                }
            case .unauthorized(_):
                Logger.w("Unathorized user. Logging out")
                UserAccount.shared.signOut()
            default:
                Logger.w("Can't handle the response.")
            }
        } catch let error {
            Logger.e("Failed to fetch transactions: \(error)")
            throw error
        }
    }
    
    func fetchRecentTransactions() async throws {
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
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
                    self.transactions = bodyJson.transactions ?? []
                }
            case .unauthorized(_):
                Logger.w("Unathorized user. Logging out")
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
