//
//  BudgetService.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 4
//  Replaces: Model/BudgetService.swift (legacy OpenAPI client)
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Data Models

/// Total balance across all accounts
struct TotalBalance: Codable, Equatable {
    let balance: Double
    let asOf: String?
    let iso_currency_code: String

    enum CodingKeys: String, CodingKey {
        case balance
        case asOf = "as_of"
        case iso_currency_code
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: balance)) ?? "$0.00"
    }
}

/// Spending breakdown by category
struct CategoryBreakdownItem: Codable, Identifiable, Equatable {
    let category: String
    let totalSpent: Double
    let transactionCount: Int
    let percentOfTotal: Double?
    let weekly_spend: Double
    let monthly_spend: Double
    let yearly_spend: Double

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case totalSpent = "total_spent"
        case transactionCount = "transaction_count"
        case percentOfTotal = "percent_of_total"
        case weekly_spend
        case monthly_spend
        case yearly_spend
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalSpent)) ?? "$0.00"
    }

    var formattedPercent: String {
        guard let percent = percentOfTotal else { return "" }
        return String(format: "%.1f%%", percent)
    }
}

/// Response containing category breakdown
struct CategoryBreakdownResponse: Codable, Equatable {
    let breakdown: [CategoryBreakdownItem]
    let startDate: String
    let endDate: String
    let totalSpent: Double

    enum CodingKeys: String, CodingKey {
        case breakdown
        case startDate = "start_date"
        case endDate = "end_date"
        case totalSpent = "total_spent"
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalSpent)) ?? "$0.00"
    }
}

/// Date range for spending analysis
enum SpendDateRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: Self { self }

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// Get start date for this range
    func startDate() -> String {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let startDate: Date
        switch self {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }

        return dateFormatter.string(from: startDate)
    }

    /// Get end date (today)
    func endDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter.string(from: Date())
    }
}

// MARK: - Service

/// Service for budget and spending analysis via Supabase direct database access
@MainActor
class BudgetService: ObservableObject {
    @Published var totalBalance: TotalBalance? = nil
    @Published var spendBreakdownResponse: CategoryBreakdownResponse? = nil
    @Published var isLoadingBalance: Bool = false
    @Published var isLoadingBreakdown: Bool = false
    @Published var balanceError: Error? = nil
    @Published var breakdownError: Error? = nil
    
    // Budget profile data
    @Published var monthlyIncome: Double = 0
    @Published var monthlyMandatoryExpenses: Double = 0
    @Published var discretionaryBudget: Double = 0

    private let supabase = SupabaseManager.shared.client

    var spendBreakdownItems: [CategoryBreakdownItem] {
        spendBreakdownResponse?.breakdown ?? []
    }

    // MARK: - Public Methods

    /// Fetch total balance across all visible accounts
    func fetchTotalBalance() async throws {
        isLoadingBalance = true
        balanceError = nil

        defer {
            isLoadingBalance = false
        }

        Logger.d("BudgetService: Fetching total balance")

        do {
            // Query all non-hidden accounts and sum their balances
            let accounts: [AccountBalance] = try await supabase
                .from("accounts")
                .select("current_balance")
                .eq("hidden", value: false)
                .execute()
                .value

            let total = accounts.reduce(0) { $0 + $1.currentBalance }

            Logger.i("BudgetService: Total balance: $\(total) across \(accounts.count) accounts")

            self.totalBalance = TotalBalance(
                balance: total,
                asOf: ISO8601DateFormatter().string(from: Date()),
                iso_currency_code: "USD"
            )
        } catch {
            Logger.e("BudgetService: Failed to fetch total balance: \(error)")
            self.balanceError = error
            throw error
        }
    }

    /// Fetch spending breakdown by category
    /// - Parameter range: Time range for analysis
    func fetchSpendingBreakdown(range: SpendDateRange = .month) async throws {
        isLoadingBreakdown = true
        breakdownError = nil

        defer {
            isLoadingBreakdown = false
        }

        let startDate = range.startDate()
        let endDate = range.endDate()

        Logger.d("BudgetService: Fetching spending breakdown (\(range.displayName): \(startDate) to \(endDate))")

        do {
            // Fetch all expense transactions in date range
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("transactions_table")
                .select()
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .lt("amount", value: 0) // Only expenses (negative amounts)
                .order("date", ascending: false)
                .execute()
                .value

            Logger.i("BudgetService: Received \(transactions.count) expense transactions")

            // Group by category and calculate totals
            var categoryMap: [String: CategoryData] = [:]
            var totalSpent: Double = 0

            for transaction in transactions {
                let category = transaction.category?.first ?? "Uncategorized"
                let amount = abs(transaction.amount)

                totalSpent += amount

                if var existing = categoryMap[category] {
                    existing.totalSpent += amount
                    existing.transactionCount += 1
                    categoryMap[category] = existing
                } else {
                    categoryMap[category] = CategoryData(
                        totalSpent: amount,
                        transactionCount: 1
                    )
                }
            }

            // Create breakdown items with percentages
            var breakdownItems: [CategoryBreakdownItem] = []
            for (category, data) in categoryMap {
                let percent = totalSpent > 0 ? (data.totalSpent / totalSpent * 100) : 0

                // Set the appropriate spend field based on the range
                let weeklySpend = range == .week ? data.totalSpent : 0
                let monthlySpend = range == .month ? data.totalSpent : 0
                let yearlySpend = range == .year ? data.totalSpent : 0

                let item = CategoryBreakdownItem(
                    category: category,
                    totalSpent: data.totalSpent,
                    transactionCount: data.transactionCount,
                    percentOfTotal: percent,
                    weekly_spend: weeklySpend,
                    monthly_spend: monthlySpend,
                    yearly_spend: yearlySpend
                )
                breakdownItems.append(item)
            }

            // Sort by amount descending
            breakdownItems.sort { $0.totalSpent > $1.totalSpent }

            self.spendBreakdownResponse = CategoryBreakdownResponse(
                breakdown: breakdownItems,
                startDate: startDate,
                endDate: endDate,
                totalSpent: totalSpent
            )
            
            // Recalculate discretionary budget now that we have spending data
            calculateDiscretionaryBudget()

            Logger.i("BudgetService: Spending breakdown complete (\(breakdownItems.count) categories, total: $\(totalSpent))")
        } catch {
            Logger.e("BudgetService: Failed to fetch spending breakdown: \(error)")
            self.breakdownError = error
            throw error
        }
    }

    /// Get top spending categories
    /// - Parameter limit: Number of top categories to return
    /// - Returns: Top spending categories
    func topSpendingCategories(limit: Int = 5) -> [CategoryBreakdownItem] {
        Array(spendBreakdownItems.prefix(limit))
    }

    /// Clear cached data
    func clearCache() {
        totalBalance = nil
        spendBreakdownResponse = nil
        monthlyIncome = 0
        monthlyMandatoryExpenses = 0
        discretionaryBudget = 0
        Logger.d("BudgetService: Cleared cache")
    }

    /// Fetch budget summary from user profile
    func fetchBudgetSummary() async {
        guard let userId = UserAccount.shared.currentUser?.id else {
            Logger.e("BudgetService: Cannot fetch budget summary - no user ID")
            return
        }
        
        Logger.d("BudgetService: Fetching budget summary for \(userId)")
        
        do {
            // Select all fields (*) to avoid decoding errors for Profile struct
            let profile: Profile = try await supabase
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.monthlyIncome = profile.monthlyIncome
            self.monthlyMandatoryExpenses = profile.monthlyMandatoryExpenses
            Logger.i("BudgetService: Loaded profile successfully for \(userId)")
            Logger.d("BudgetService: -> monthly_income: \(monthlyIncome)")
            Logger.d("BudgetService: -> monthly_mandatory_expenses: \(monthlyMandatoryExpenses)")
            
            calculateDiscretionaryBudget()
        } catch {
            Logger.e("BudgetService: Failed to fetch budget summary: \(error)")
        }
    }

    /// Calculate discretionary budget: income - fixed expenses - non-fixed monthly spending
    func calculateDiscretionaryBudget() {
        let totalMonthlySpent = spendBreakdownResponse?.totalSpent ?? 0
        
        Logger.d("BudgetService: --- Budget Calculation ---")
        Logger.d("BudgetService: 1. Monthly Income (from profile): \(monthlyIncome)")
        Logger.d("BudgetService: 2. Fixed Expenses (from profile): \(monthlyMandatoryExpenses)")
        Logger.d("BudgetService: 3. Fun Spending (Current Month): \(totalMonthlySpent)")
        
        // Simple formula: Income - Mandatory - Current Spend
        let result = max(0, monthlyIncome - monthlyMandatoryExpenses - totalMonthlySpent)
        self.discretionaryBudget = result
        
        Logger.i("BudgetService: => Resulting Discretionary Budget: \(discretionaryBudget)")
        
        if monthlyIncome <= 0 {
            Logger.w("BudgetService: Caution - monthlyIncome is 0 or less, check if gemini-budget-analysis completed successfully")
        }
    }

    /// Check if budget analysis exists and trigger it if missing but accounts are linked
    func checkAndTriggerBudgetAnalysis() async {
        Logger.d("BudgetService: Checking if budget analysis is needed")
        
        do {
            // Define minimal local struct for existence checking
            struct IDOnly: Codable { let id: Int }
            
            // 1. Check if we already have budget items
            let budgetItems: [IDOnly] = try await supabase
                .from("budget_items_table")
                .select("id")
                .limit(1)
                .execute()
                .value
            
            if !budgetItems.isEmpty {
                Logger.d("BudgetService: Budget analysis already exists")
                return
            }
            
            // 2. No budget items, check if we have any accounts linked
            // We'll check items_table directly as it's the source of truth for bank connections
            let items: [IDOnly] = try await supabase
                .from("items_table")
                .select("id")
                .limit(1)
                .execute()
                .value
            
            if items.isEmpty {
                Logger.d("BudgetService: No accounts (items) linked, skipping budget analysis")
                return
            }
            
            // 3. We have accounts but no budget analysis - trigger it!
            Logger.i("BudgetService: Triggering Gemini budget analysis for user with linked accounts")
            
            guard let userId = UserAccount.shared.currentUser?.id else {
                Logger.e("BudgetService: Missing user ID for budget analysis")
                return
            }
            
            let body = ["user_id": userId]
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            // Invoke the Edge Function (we don't necessarily need to wait for it or handle the result here
            // as it runs in the background and updates the DB)
            try await supabase.functions.invoke(
                "gemini-budget-analysis",
                options: FunctionInvokeOptions(body: bodyData)
            )
            
            Logger.i("BudgetService: Gemini budget analysis triggered successfully")
            
        } catch {
            Logger.e("BudgetService: Failed to check/trigger budget analysis: \(error)")
        }
    }
}

// MARK: - Private Models

/// Simple account balance model for aggregation
private struct AccountBalance: Codable {
    let currentBalance: Double

    enum CodingKeys: String, CodingKey {
        case currentBalance = "current_balance"
    }
}

/// Transaction model for breakdown analysis
private struct TransactionForBreakdown: Codable {
    let id: Int
    let amount: Double
    let category: [String]?
}

/// Temporary data structure for category aggregation
private struct CategoryData {
    var totalSpent: Double
    var transactionCount: Int
}
