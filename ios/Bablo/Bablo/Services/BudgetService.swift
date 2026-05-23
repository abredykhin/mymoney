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

/// A recurring transaction stream from Plaid or user-created
struct RecurringStream: Codable, Identifiable, Equatable {
    let id: Int
    let plaidStreamId: String?
    let description: String
    let merchantName: String?
    let personalFinanceCategory: String?  // Matches DB: stores PRIMARY value
    let personalFinanceSubcategory: String?  // Matches DB: stores DETAILED value
    let frequency: String // WEEKLY, SEMI_MONTHLY, MONTHLY, ANNUALLY
    let averageAmount: Double
    let monthlyAmount: Double
    let isoCurrencyCode: String?
    let type: String // income or expense
    let status: String // MATURE, EARLY_DETECTION, TOMBSTONED, MANUAL
    let isActive: Bool
    let firstDate: String?
    let lastDate: String?
    let predictedNextDate: String?
    let isUserModified: Bool
    let userMarkedRecurring: Bool?
    let isExcluded: Bool
    let isManual: Bool
    let matchPattern: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plaidStreamId = "plaid_stream_id"
        case description
        case merchantName = "merchant_name"
        case personalFinanceCategory = "personal_finance_category"
        case personalFinanceSubcategory = "personal_finance_subcategory"
        case frequency
        case averageAmount = "average_amount"
        case monthlyAmount = "monthly_amount"
        case isoCurrencyCode = "iso_currency_code"
        case type
        case status
        case isActive = "is_active"
        case firstDate = "first_date"
        case lastDate = "last_date"
        case predictedNextDate = "predicted_next_date"
        case isUserModified = "is_user_modified"
        case userMarkedRecurring = "user_marked_recurring"
        case isExcluded = "is_excluded"
        case isManual = "is_manual"
        case matchPattern = "match_pattern"
    }

    /// Human-readable frequency label
    var frequencyDisplay: String {
        switch frequency {
        case "WEEKLY": return "Weekly"
        case "SEMI_MONTHLY": return "Twice Monthly"
        case "MONTHLY": return "Monthly"
        case "ANNUALLY": return "Yearly"
        default: return frequency.capitalized
        }
    }
}

/// Request model for creating manual recurring stream
struct CreateManualStreamRequest: Codable {
    let transaction_id: Int
    let frequency: String
    let user_id: String
}

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
            // Get the first day of the current month
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? now
        case .year:
            // Get the first day of the current year
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: components) ?? now
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

/// A recurring budget item identified by Gemini
struct BudgetItem: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let pattern: String
    let amount: Double
    let frequency: String
    let monthlyAmount: Double
    let type: String
    let confidence: Double
    let is_active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pattern
        case amount
        case frequency
        case monthlyAmount = "monthly_amount"
        case type
        case confidence
        case is_active
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
    @Published var variableBudget: Double = 0  // Renamed from discretionaryBudget
    @Published var allBudgetItems: [BudgetItem] = []
    @Published var allRecurringStreams: [RecurringStream] = []
    
    // Dynamic income data
    @Published var knownIncomeThisMonth: Double = 0
    @Published var extraIncomeThisMonth: Double = 0
    
    // Variable spend tracking (for Home Screen)
    @Published var variableSpend: Double = 0
    
    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    // Total spend (for Spend Tab)
    var spendBreakdownItems: [CategoryBreakdownItem] {
        spendBreakdownResponse?.breakdown ?? []
    }
    
    // MARK: - Hero Card Helpers
    
    /// Estimated total variable spending for the month
    var variableSpendingProjection: Double {
        let currentVariableSpend = variableSpend
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get number of days in current month
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return currentVariableSpend }
        let totalDaysInMonth = Double(range.count)
        
        // Get current day of month
        let currentDay = Double(calendar.component(.day, from: now))
        
        // Avoid division by zero
        if currentDay == 0 { return 0 }
        
        // Simple linear extrapolation
        return (currentVariableSpend / currentDay) * totalDaysInMonth
    }
    
    var daysRemainingInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 0 }
        let totalDays = range.count
        let currentDay = calendar.component(.day, from: now)
        return max(0, totalDays - currentDay)
    }
    
    var daysRemainingInCurrentWeek: Int {
        // Assuming week ends on Saturday (or standard Gregorian). 
        // 1 = Sunday, 7 = Saturday.
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) // 1...7
        // Let's assume we want days left including today? Or remaining?
        // "Safe to spend for the rest of this week" implies remaining days.
        // If today is Monday (2), and week ends Saturday (7), we have Tue, Wed, Thu, Fri, Sat = 5 days.
        // Let's strictly say "Days until end of week".
        // Use user's locale for week definition?
        // Simple approach: 7 - weekday + 1 (if we count today) or just strict remaining.
        // User asked: "how many days are left in this week"
        
        // Support Sunday-start or Monday-start based on Locale?
        // Let's use 7 (Saturday) as end for standard US, but let's standardise to "End of Week" 
        // being the start of next week - 1 day.
        
        // Simple logic: Days until the next Sunday (start of new week).
        // If today is Sunday (1), days remaining = 6 (Mon-Sat)? Or is Sunday the end?
        // Let's assume standard ISO week (Monday start)? Or US (Sunday start)?
        // MyMoney seems generic. Let's assume "Rest of this week" means until next Monday?? 
        // Or until Saturday night?
        
        // Let's go with: Week ends on Saturday.
        
        // If today is Friday (6), days left = 1 (Saturday).
        // If today is Saturday (7), days left = 0.
        
        // Let's include TODAY in the logic "Safe to spend THIS week", usually implies the budget for `today...end_of_week`.
        // So if today is Fri, I have budget for Fri, Sat. = 2 days.
        
        return 7 - weekday + 1
    }

    // MARK: - Public Methods

    /// Fetch total balance across all visible accounts
    /// Logic: Net Available Cash = (Depository Accounts) - (Credit Card Debt)
    func fetchTotalBalance() async throws {
        isLoadingBalance = true
        balanceError = nil

        defer {
            isLoadingBalance = false
        }

        Logger.d("BudgetService: Fetching total balance")

        do {
            // Query all non-hidden accounts
            let accounts: [AccountBalance] = try await supabase
                .from("accounts")
                .select("current_balance, type") // Select type to filter logic
                .eq("hidden", value: false)
                .execute()
                .value

            // Calculate Net Available Cash
            // 1. Add Depository (Checking, Savings, etc.)
            // 2. Subtract Credit (Credit Card debt, which is usually positive in Plaid/DB)
            // 3. Ignore Investments, Loans, etc. for "Cash" metric
            let total = accounts.reduce(0.0) { result, account in
                if account.type.caseInsensitiveCompare("depository") == .orderedSame {
                    // Money we have
                    return result + account.currentBalance
                } else if account.type.caseInsensitiveCompare("credit") == .orderedSame {
                    // Money we owe (Debt) - Subtract it from available cash
                    // Assuming positive balance means debt (standard Plaid)
                    return result - account.currentBalance
                }
                return result
            }

            Logger.i("BudgetService: Net Available Cash: $\(total) (from \(accounts.count) accounts)")

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

    /// Fetch variable spending (filtered by DB view) for the current month
    /// Used for Home Screen Budget Calculation
    func fetchVariableSpend(range: SpendDateRange = .month) async throws {
        // We typically care about the current month for budget
        // but can support other ranges if needed.
        // For now, let's stick to current month logic for the Home Screen.
        
        let startDate = range.startDate()
        let endDate = range.endDate()
        
        Logger.d("BudgetService: Fetching variable spend (\(range.displayName))")
        
        do {
            // Use the NEW DB View 'variable_transactions' which already filters out fixed expenses
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("variable_transactions")
                .select("id, amount, name, personal_finance_category, type") // Select all required fields for TransactionForBreakdown decoding
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .gt("amount", value: 0) // Expenses only
                .not("personal_finance_category", operator: .ilike, value: "%transfer%")
                .execute()
                .value
            
            let total = transactions.reduce(0) { $0 + abs($1.amount) }
            
            DispatchQueue.main.async {
                self.variableSpend = total
                self.calculateVariableBudget()
            }
            
            Logger.i("BudgetService: Variable Spend (DB filtered): $\(total)")
        } catch {
            Logger.e("BudgetService: Failed to fetch variable spend: \(error)")
        }
    }

    /// Fetch TOTAL spending breakdown (Unfiltered)
    /// Used for Spend Tab
    /// - Parameter range: Time range for analysis
    func fetchTotalSpend(range: SpendDateRange = .month) async throws {
        isLoadingBreakdown = true
        breakdownError = nil

        defer {
            isLoadingBreakdown = false
        }

        let startDate = range.startDate()
        let endDate = range.endDate()

        Logger.d("BudgetService: Fetching TOTAL spending breakdown (\(range.displayName))")

        do {
            // Use standard 'transactions' view - NO Filtering
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("transactions")
                .select("id, amount, name, personal_finance_category, type")
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .gt("amount", value: 0) // Positive amounts are expenses
                .not("personal_finance_category", operator: .ilike, value: "%transfer%") 
                .order("date", ascending: false)
                .execute()
                .value

            Logger.i("BudgetService: Received \(transactions.count) total transactions for breakdown")

            // No client-side filtering needed anymore for Spend Tab!
            // We want to see Rent/Mortgage here.
            
            // Group by category and calculate totals
            var categoryMap: [String: CategoryData] = [:]
            var totalSpent: Double = 0

            for transaction in transactions {
                // In Supabase, personal_finance_category is a string
                let category = transaction.personalFinanceCategory ?? "Uncategorized"
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
            
            // Note: We do NOT calculate variable budget here anymore.
            // That is handled by fetchVariableSpend().

            Logger.i("BudgetService: Total spending breakdown complete (\(breakdownItems.count) categories, total: $\(totalSpent))")
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
        variableBudget = 0
        variableSpend = 0
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
            Logger.d("BudgetService: -> monthly_income (expected): \(monthlyIncome)")
            Logger.d("BudgetService: -> monthly_mandatory_expenses: \(monthlyMandatoryExpenses)")
            
            await fetchRecurringStreams() // CHANGED: was fetchBudgetItems()
            await fetchActualIncome()
            try? await fetchVariableSpend() // Fetch variable spend to calc budget
        } catch {
            Logger.e("BudgetService: Failed to fetch budget summary: \(error)")
        }
    }

    /// Fetch all recurring streams (income and expenses) from Plaid
    func fetchRecurringStreams() async {
        guard let userId = UserAccount.shared.currentUser?.id else { return }

        do {
            let streams: [RecurringStream] = try await supabase
                .from("recurring_streams_table")
                .select("*")
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .eq("is_excluded", value: false)
                .execute()
                .value

            self.allRecurringStreams = streams
            Logger.i("BudgetService: Loaded \(streams.count) recurring streams from Plaid")
        } catch {
            Logger.e("BudgetService: Failed to fetch recurring streams: \(error)")
        }
    }

    /// Fetch actual income transactions for the current month and categorize them
    func fetchActualIncome() async {
        guard let userId = UserAccount.shared.currentUser?.id else { return }
        
        let range = SpendDateRange.month
        let startDate = range.startDate()
        let endDate = range.endDate()
        
        do {
            // Fetch all income transactions in date range from the 'transactions' view to get account type
            // Sign logic: Negative amounts are income
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("transactions")
                .select("amount, name, type, is_recurring")
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .lt("amount", value: 0) // Negative = Money In
                .execute()
                .value
            
            let incomeStreams = allRecurringStreams
                .filter { $0.type == "income" }
            
            var knownTotal: Double = 0
            var extraTotal: Double = 0
            
            for tx in transactions {
                // LIABILITY ACCOUNT INFLOW RULE: Ignore inflows on credit/loan accounts
                if tx.type == "credit" || tx.type == "loan" {
                    Logger.d("BudgetService: Ignoring income-like transaction on \(tx.type ?? "unknown") account: \(tx.name)")
                    continue
                }
                
                let amount = abs(tx.amount)
                
                // If already marked as recurring by backend, count as known
                if tx.isRecurring == true {
                    knownTotal += amount
                } else {
                    // This is a one-off income transaction
                    extraTotal += amount
                }
            }
            
            self.knownIncomeThisMonth = knownTotal
            self.extraIncomeThisMonth = extraTotal
            
            Logger.i("BudgetService: Income Analysis - Known: $\(knownTotal), Extra: $\(extraTotal)")
            
        } catch {
            Logger.e("BudgetService: Failed to fetch actual income: \(error)")
        }
    }

    /// Effective income: max(expected, known) + extra
    /// Use this for UI displays instead of raw monthlyIncome
    var effectiveIncome: Double {
        max(monthlyIncome, knownIncomeThisMonth) + extraIncomeThisMonth
    }

    /// Calculate variable budget: (max(expected, known) + extra) - mandatory - variable_spending
    func calculateVariableBudget() {
        // Use the fetched variable spend from DB view
        let totalMonthlyVariableSpent = variableSpend
        
        Logger.d("BudgetService: --- Budget Calculation ---")
        Logger.d("BudgetService: 1. Expected Baseline Income: \(monthlyIncome)")
        Logger.d("BudgetService: 2. Known Income Received: \(knownIncomeThisMonth)")
        Logger.d("BudgetService: 3. Extra Income Received: \(extraIncomeThisMonth)")
        
        // Smarter income logic:
        // Use the higher of expected vs known patterns (handles 3 paychecks)
        // AND always add extra one-offs on top
        let incomeToUse = effectiveIncome
        
        Logger.d("BudgetService: 4. Effective Income: \(incomeToUse)")
        Logger.d("BudgetService: 5. Fixed Expenses (Profile): \(monthlyMandatoryExpenses)")
        Logger.d("BudgetService: 6. Variable Spending (Current Month): \(totalMonthlyVariableSpent)")
        
        let result = incomeToUse - monthlyMandatoryExpenses - totalMonthlyVariableSpent
        self.variableBudget = result
        
        Logger.i("BudgetService: => Resulting Variable Budget: \(variableBudget)")
        
        if monthlyIncome <= 0 && knownIncomeThisMonth <= 0 {
            Logger.w("BudgetService: Caution - No income source found yet")
        }
    }

    /// Manually trigger a recurring transaction sync from Plaid
    func syncRecurringTransactions() async throws {
        Logger.d("BudgetService: Triggering recurring transaction sync")

        // Get user's first item (or iterate through all items)
        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetError.noUser
        }

        struct ItemID: Codable { let plaid_item_id: String }
        let items: [ItemID] = try await supabase
            .from("items_table")
            .select("plaid_item_id")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
            .value

        guard let firstItem = items.first else {
            Logger.w("BudgetService: No active items found for recurring sync")
            return
        }

        let body = [
            "plaid_item_id": firstItem.plaid_item_id,
            "user_id": userId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        try await supabase.functions.invoke(
            "sync-recurring-transactions",
            options: FunctionInvokeOptions(body: bodyData)
        )

        Logger.i("BudgetService: Recurring transaction sync triggered")

        // Refresh data after sync
        await fetchBudgetSummary()
    }

    /// Create a manual recurring stream from a transaction
    func createManualStream(transactionId: Int, frequency: String) async throws {
        Logger.d("BudgetService: Creating manual stream for transaction \(transactionId)")

        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetError.noUser
        }

        let body: [String: Any] = [
            "transaction_id": transactionId,
            "frequency": frequency,
            "user_id": userId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response = try await supabase.functions.invoke(
            "create-manual-stream",
            options: FunctionInvokeOptions(body: bodyData)
        )

        Logger.i("BudgetService: Manual stream created successfully")

        // Refresh data after creating stream
        await fetchBudgetSummary()
    }

    /// Delete a manual recurring stream
    func deleteManualStream(streamId: Int) async throws {
        Logger.d("BudgetService: Deleting manual stream \(streamId)")

        try await supabase
            .from("recurring_streams_table")
            .delete()
            .eq("id", value: streamId)
            .eq("is_manual", value: true) // Safety: only allow deleting manual streams
            .execute()

        Logger.i("BudgetService: Manual stream deleted")

        // Refresh data after deletion
        await fetchBudgetSummary()
    }

    enum BudgetError: Error {
        case noUser
    }
}

// MARK: - Private Models

/// Simple account balance model for aggregation
/// Simple account balance model for aggregation
private struct AccountBalance: Codable {
    let currentBalance: Double
    let type: String

    enum CodingKeys: String, CodingKey {
        case currentBalance = "current_balance"
        case type
    }
}

/// Transaction model for breakdown analysis
private struct TransactionForBreakdown: Codable {
    let id: Int?
    let amount: Double
    let name: String
    let personalFinanceCategory: String?
    let type: String?
    let isRecurring: Bool? // NEW

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case name
        case personalFinanceCategory = "personal_finance_category"
        case type
        case isRecurring = "is_recurring"
    }
}

/// Temporary data structure for category aggregation
private struct CategoryData {
    var totalSpent: Double
    var transactionCount: Int
}
