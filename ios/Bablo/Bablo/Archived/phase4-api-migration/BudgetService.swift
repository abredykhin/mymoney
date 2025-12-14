//
//  BudgetService.swift
//  Bablo
//
//  Created by Anton Bredykhin on 10/13/24.
//

import Foundation

typealias TotalBalance = Components.Schemas.TotalBalance
typealias CategoryBreakdownResponse = Components.Schemas.CategoryBreakdownResponse
typealias CategoryBreakdownItem = Components.Schemas.CategoryBreakdownItem

enum SpendDateRange: String, CaseIterable, Identifiable {
    case week, month, year
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

@MainActor
class BudgetService: ObservableObject {
    @Published var totalBalance: TotalBalance? = nil
    @Published var spendBreakdownResponse: CategoryBreakdownResponse? = nil
    @Published var isLoadingBreakdown: Bool = false
    @Published var breakdownError: Error? = nil
    
    var spendBreakdownItems: [CategoryBreakdownItem] {
        spendBreakdownResponse?.breakdown ?? []
    }
    
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
    
    func fetchSpendBreakdown(period: SpendDateRange ) async throws {
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
            return
        }
        
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = formatter.string(from: currentDate)
        
        Logger.i("Fetching spend breakdown from server using current date: \(dateString)")
        
        do {
            let response = try await client.categoryBreakdown(
                query: .init(currentDate: dateString)
            )
            
            switch (response) {
            case .ok(let json):
                switch (json.body) {
                case .json(let breakdown):
                    Logger.i("Successfully fetched spend breakdown")
                    spendBreakdownResponse = breakdown
                }
            case .badRequest(_):
                Logger.e("Failed to fetch spend breakdown: Bad Request")
            case .unauthorized(_):
                Logger.e("Failed to fetch spend breakdown: Unauthorized")
            default:
                Logger.e("Failed to fetch spend breakdown: Unknown error")
            }
        } catch let error {
            Logger.e("Failed to fetch spend breakdown: \(error)")
            throw error
        }
    }
}
