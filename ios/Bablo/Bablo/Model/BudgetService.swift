//
//  BudgetService.swift
//  Bablo
//
//  Created by Anton Bredykhin on 10/13/24.
//

import Foundation

typealias TotalBalance = Components.Schemas.TotalBalance

@MainActor
class BudgetService: ObservableObject {
    @Published var totalBalance: TotalBalance? = nil

    func fetchTotalBalance() async throws {
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
            return
        }
        
        Logger.d("Fetching total balance from server")
        
        do {
            let response = try await client.getTotalBudget()
            
            switch (response) {
            case .ok(let json):
                switch(json.body) {
                case .json(let totalBalance):
                    Logger.i("Successfully fetched total balance: \(totalBalance.balance)")
                    self.totalBalance = totalBalance
                }
            case .unauthorized(_):
                Logger.w("Unathorized user. Logging out")
                UserAccount.shared.signOut()
            default:
                Logger.w("Can't handle the response.")
            }
        } catch let error {
            Logger.e("Failed to fetch total balance: \(error)")
            throw error
        }

    }
}
