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
    
    // Dynamic income data
    @Published var knownIncomeThisMonth: Double = 0
    @Published var extraIncomeThisMonth: Double = 0
    
    // Variable spend tracking (for Home Screen)
    @Published var variableSpend: Double = 0
    
    private let supabase = SupabaseManager.shared.client

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
            
            await fetchBudgetItems()
            await fetchActualIncome()
            try? await fetchVariableSpend() // Fetch variable spend to calc budget
        } catch {
            Logger.e("BudgetService: Failed to fetch budget summary: \(error)")
        }
    }

    /// Fetch all recurring budget items (income and expenses)
    func fetchBudgetItems() async {
        guard let userId = UserAccount.shared.currentUser?.id else { return }
        
        do {
            let items: [BudgetItem] = try await supabase
                .from("budget_items_table")
                .select("*")
                .eq("user_id", value: userId)
                .gte("confidence", value: 0.85)
                .eq("is_active", value: true)
                .execute()
                .value
            
            self.allBudgetItems = items
            Logger.i("BudgetService: Loaded \(items.count) highly confident budget patterns")
        } catch {
            Logger.e("BudgetService: Failed to fetch budget items: \(error)")
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
                .select("amount, name, type")
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .lt("amount", value: 0) // Negative = Money In
                .execute()
                .value
            
            let incomePatterns = allBudgetItems
                .filter { $0.type == "income" }
                .map { (pattern: $0.pattern.lowercased(), name: $0.name) }
            
            var knownTotal: Double = 0
            var extraTotal: Double = 0
            
            for tx in transactions {
                // LIABILITY ACCOUNT INFLOW RULE: Ignore inflows on credit/loan accounts
                if tx.type == "credit" || tx.type == "loan" {
                    Logger.d("BudgetService: Ignoring income-like transaction on \(tx.type ?? "unknown") account: \(tx.name)")
                    continue
                }
                
                let txName = tx.name.lowercased()
                let amount = abs(tx.amount)
                
                let matchingPattern = incomePatterns.first { txName.contains($0.pattern) }
                
                if let pattern = matchingPattern {
                    Logger.d("BudgetService: Categorized as KNOWN income: \(tx.name) ($\(amount)) matching '\(pattern.name)'")
                    knownTotal += amount
                } else {
                    Logger.d("BudgetService: Categorized as EXTRA income: \(tx.name) ($\(amount))")
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

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case name
        case personalFinanceCategory = "personal_finance_category"
        case type
    }
}

/// Temporary data structure for category aggregation
private struct CategoryData {
    var totalSpent: Double
    var transactionCount: Int
}
