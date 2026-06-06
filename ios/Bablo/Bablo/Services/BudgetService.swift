//
//  BudgetService.swift
//  Bablo
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
    let personalFinanceCategory: String?
    let personalFinanceSubcategory: String?
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
    let accountId: Int?

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
        case accountId = "account_id"
    }

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
struct BudgetCategoryItem: Codable, Identifiable, Equatable {
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
    let breakdown: [BudgetCategoryItem]
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

struct HeroSpendBreakdownRow: Identifiable, Equatable {
    var id: String { category }
    let category: String
    let amount: Double
    let transactionCount: Int
    let examples: [String]

    var detail: String {
        if examples.isEmpty {
            return "\(transactionCount) transaction\(transactionCount == 1 ? "" : "s")"
        }
        return examples.joined(separator: ", ")
    }
}

struct HeroIncomeBreakdownRow: Identifiable, Equatable {
    var id: String { "\(name)-\(amount)" }
    let name: String
    let amount: Double
    let isRecurring: Bool
    var isProjected: Bool = false
    var detailOverride: String? = nil
}

struct HeroExcludedTransactionRow: Identifiable, Equatable {
    var id: String { "\(name)-\(detail)-\(amount)" }
    let name: String
    let detail: String
    let amount: Double

    var displayAmount: String {
        let rounded = Int(abs(amount).rounded())
        return "$\(rounded.formatted())"
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

    func startDate() -> String {
        let calendar = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = calendar
        fmt.timeZone = calendar.timeZone

        let startDate: Date
        switch self {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? now
        case .year:
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: components) ?? now
        }

        return fmt.string(from: startDate)
    }

    func endDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = Calendar.bablo.timeZone
        return fmt.string(from: Date())
    }
}

/// Driving the Week Day Spending Energy Chart
struct DailyEnergyItem: Codable, Identifiable, Equatable {
    var id: String { weekday }
    let weekday: String
    let dateLabel: String
    let totalSpent: Double
    let isPeak: Bool
    let peakMerchant: String
    let peakCategory: String?
    let peakAmount: Double

    enum CodingKeys: String, CodingKey {
        case weekday
        case dateLabel = "date_label"
        case totalSpent = "total_spent"
        case isPeak = "is_peak"
        case peakMerchant = "peak_merchant"
        case peakCategory = "peak_category"
        case peakAmount = "peak_amount"
    }
}

/// Driving the Top Merchants Lineup List
struct TopMerchantItem: Codable, Identifiable, Equatable {
    var id: String { merchantName }
    let merchantName: String
    let totalSpent: Double
    let transactionCount: Int
    let personalFinanceCategory: String?

    enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case totalSpent = "total_spent"
        case transactionCount = "transaction_count"
        case personalFinanceCategory = "personal_finance_category"
    }
}

/// Driving the Daily Spending Streak Card
struct UserStreak: Codable, Equatable {
    let currentStreak: Int
    let maxStreak: Int
    let last28DaysStatus: [Bool]

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case maxStreak = "max_streak"
        case last28DaysStatus = "last_28_days_status"
    }
}

// MARK: - get_budget_state RPC model

struct BudgetStateRow: Codable, Equatable {
    let poolTotal:          Double
    let poolRemaining:      Double
    let dailyPace:          Double
    let weeklyPace:         Double
    let spentToday:         Double
    let spentWeek:          Double
    let spentMtd:           Double
    let prevDaySpent:       Double
    let prevWeekSpent:      Double
    let prevMonthSpent:     Double
    let effectiveIncome:    Double
    let mandatory:          Double
    let goalsSetAside:      Double
    let netCash:            Double
    let upcomingBills:      Double
    let incomeBasis:        IncomeBasis
    let daysInMonth:        Int
    let daysRemaining:      Int
    let daysElapsedInWeek:  Int
    let knownIncome:        Double
    let extraIncome:        Double

    enum CodingKeys: String, CodingKey {
        case poolTotal         = "pool_total"
        case poolRemaining     = "pool_remaining"
        case dailyPace         = "daily_pace"
        case weeklyPace        = "weekly_pace"
        case spentToday        = "spent_today"
        case spentWeek         = "spent_week"
        case spentMtd          = "spent_mtd"
        case prevDaySpent      = "prev_day_spent"
        case prevWeekSpent     = "prev_week_spent"
        case prevMonthSpent    = "prev_month_spent"
        case effectiveIncome   = "effective_income"
        case mandatory
        case goalsSetAside     = "goals_set_aside"
        case netCash           = "net_cash"
        case upcomingBills     = "upcoming_bills"
        case incomeBasis       = "income_basis"
        case daysInMonth       = "days_in_month"
        case daysRemaining     = "days_remaining"
        case daysElapsedInWeek = "days_elapsed_in_week"
        case knownIncome       = "known_income"
        case extraIncome       = "extra_income"
    }
}

// MARK: - Service

@MainActor
class BudgetService: ObservableObject {

    @Published var totalBalance: TotalBalance? = nil
    @Published var spendBreakdownResponse: CategoryBreakdownResponse? = nil
    @Published var isLoadingBalance: Bool = false
    @Published var isLoadingBreakdown: Bool = false
    @Published var balanceError: Error? = nil
    @Published var breakdownError: Error? = nil

    @Published var monthlyIncome: Double = 0
    @Published var monthlyMandatoryExpenses: Double = 0
    @Published var variableBudget: Double = 0

    @Published var knownIncomeThisMonth: Double = 0
    @Published var extraIncomeThisMonth: Double = 0
    @Published var variableSpend: Double = 0
    @Published var previousDayVariableSpend: Double = 0
    @Published var previousWeekVariableSpend: Double = 0
    @Published var previousMonthVariableSpend: Double = 0
    @Published var currentWeekVariableSpend: Double = 0
    @Published var todayVariableSpend: Double = 0

    @Published var budgetState: BudgetStateRow? = nil

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    var spendBreakdownItems: [BudgetCategoryItem] {
        spendBreakdownResponse?.breakdown ?? []
    }

    // MARK: - Public Methods

    func fetchTotalBalance() async throws {
        isLoadingBalance = true
        balanceError = nil
        defer { isLoadingBalance = false }

        Logger.d("BudgetService: Fetching total balance")

        do {
            let results: [TotalBalance] = try await supabase
                .rpc("get_net_cash_balance")
                .execute()
                .value

            guard let result = results.first else {
                self.totalBalance = TotalBalance(balance: 0, asOf: nil, iso_currency_code: "USD")
                return
            }

            Logger.i("BudgetService: Net Available Cash: $\(result.balance)")
            self.totalBalance = result
        } catch {
            Logger.e("BudgetService: Failed to fetch total balance: \(error)")
            self.balanceError = error
            throw error
        }
    }

    func fetchBudgetState(incomeBasis: IncomeBasis? = nil) async {
        struct Params: Encodable {
            let p_as_of: String?
            let p_income_basis: String?
        }
        let params = Params(
            p_as_of: nil,
            p_income_basis: incomeBasis?.rawValue
        )

        do {
            let rows: [BudgetStateRow] = try await supabase
                .rpc("get_budget_state", params: params)
                .execute()
                .value

            guard let row = rows.first else {
                Logger.e("BudgetService: get_budget_state returned empty result")
                return
            }

            Logger.i("BudgetService: budget state — pool \(row.poolTotal), remaining \(row.poolRemaining)")
            self.budgetState = row

            self.variableSpend            = row.spentMtd
            self.currentWeekVariableSpend = row.spentWeek
            self.todayVariableSpend       = row.spentToday
            self.previousDayVariableSpend   = row.prevDaySpent
            self.previousWeekVariableSpend  = row.prevWeekSpent
            self.previousMonthVariableSpend = row.prevMonthSpent
            self.monthlyIncome            = row.effectiveIncome
            self.monthlyMandatoryExpenses = row.mandatory
            self.knownIncomeThisMonth     = row.knownIncome
            self.extraIncomeThisMonth     = row.extraIncome
        } catch {
            Logger.e("BudgetService: fetchBudgetState failed: \(error)")
        }
    }

    func fetchTotalSpend(range: SpendDateRange = .month) async throws {
        isLoadingBreakdown = true
        breakdownError = nil
        defer { isLoadingBreakdown = false }

        let startDate = range.startDate()
        let endDate = range.endDate()

        Logger.d("BudgetService: Fetching TOTAL spending breakdown (\(range.displayName))")

        struct Params: Encodable { let p_start: String; let p_end: String }
        struct BreakdownRow: Codable {
            let category: String
            let totalSpent: Double
            let transactionCount: Int
            let percentOfTotal: Double
            enum CodingKeys: String, CodingKey {
                case category
                case totalSpent       = "total_spent"
                case transactionCount = "transaction_count"
                case percentOfTotal   = "percent_of_total"
            }
        }

        do {
            let rows: [BreakdownRow] = try await supabase
                .rpc("get_spending_breakdown", params: Params(p_start: startDate, p_end: endDate))
                .execute()
                .value

            let totalSpent = rows.reduce(0.0) { $0 + $1.totalSpent }

            let breakdownItems = rows.map { row in
                BudgetCategoryItem(
                    category: row.category,
                    totalSpent: row.totalSpent,
                    transactionCount: row.transactionCount,
                    percentOfTotal: row.percentOfTotal,
                    weekly_spend:  range == .week  ? row.totalSpent : 0,
                    monthly_spend: range == .month ? row.totalSpent : 0,
                    yearly_spend:  range == .year  ? row.totalSpent : 0
                )
            }

            self.spendBreakdownResponse = CategoryBreakdownResponse(
                breakdown: breakdownItems,
                startDate: startDate,
                endDate: endDate,
                totalSpent: totalSpent
            )

            Logger.i("BudgetService: Total spending breakdown complete (\(breakdownItems.count) categories)")
        } catch {
            Logger.e("BudgetService: Failed to fetch spending breakdown: \(error)")
            self.breakdownError = error
            throw error
        }
    }

    func topSpendingCategories(limit: Int = 5) -> [BudgetCategoryItem] {
        Array(spendBreakdownItems.prefix(limit))
    }

    func fetchBudgetSummary() async {
        guard let userId = UserAccount.shared.currentUser?.id else {
            Logger.e("BudgetService: Cannot fetch budget summary - no user ID")
            return
        }

        Logger.d("BudgetService: Fetching budget summary for \(userId)")
        let basis = UserAccount.shared.incomeBasis
        await fetchBudgetState(incomeBasis: basis)
    }

    func clearCache() {
        totalBalance = nil
        spendBreakdownResponse = nil
        monthlyIncome = 0
        monthlyMandatoryExpenses = 0
        variableBudget = 0
        variableSpend = 0
        previousDayVariableSpend = 0
        previousWeekVariableSpend = 0
        previousMonthVariableSpend = 0
        currentWeekVariableSpend = 0
        todayVariableSpend = 0
        budgetState = nil
        Logger.d("BudgetService: Cleared cache")
    }

    var effectiveIncome: Double {
        max(monthlyIncome, knownIncomeThisMonth) + extraIncomeThisMonth
    }

    func calculateVariableBudget() {
        let totalMonthlyVariableSpent = variableSpend

        Logger.d("BudgetService: --- Budget Calculation ---")
        Logger.d("BudgetService: 1. Expected Baseline Income: \(monthlyIncome)")
        Logger.d("BudgetService: 2. Known Income Received: \(knownIncomeThisMonth)")
        Logger.d("BudgetService: 3. Extra Income Received: \(extraIncomeThisMonth)")

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

    enum BudgetError: Error {
        case noUser
    }
}
