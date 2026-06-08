import Foundation

// MARK: - Home tab navigation

/// All push-navigation destinations within the Home tab.
///
/// Only `HomeView` registers `navigationDestination(for: HomeDestination.self)`.
/// Any view nested in the Home NavigationStack can push a new screen by using
/// `NavigationLink(value: HomeDestination.xxx)` — SwiftUI resolves it up the stack.
/// Adding a new screen requires only:
///   1. A new case here.
///   2. A new `case` branch in HomeView's `.navigationDestination` switch.
enum HomeDestination: Hashable {
    /// The "How we got this" budget breakdown detail for a given period.
    case budgetBreakdown(HeroPeriod)

    /// Detail screen for the user's saving streak.
    case streakDetail

    /// The full paginated list of all transactions.
    case allTransactions

    /// The Recent-style transaction list scoped to a budget period's variable spend
    /// (opened from the "What you've spent this period" breakdown step). Uses the same
    /// AllTransactionsView the "Recent" widget opens, rather than a bespoke list.
    case periodSpendList(HeroPeriod)

    /// This month's spend that landed BEFORE the given period began — i.e. month-to-date minus
    /// the current day/week. Opened from the "Spent earlier this month" breakdown step.
    case monthSpendBeforePeriod(HeroPeriod)

    /// Transactions on a specific day (yyyy-MM-dd date string).
    case dayTransactions(String)

    /// Discretionary transactions list for a specific category and budget period.
    case categorySpendList(period: HeroPeriod, category: String)

    /// Income transactions for the current month.
    case incomeTransactions

    /// Upcoming / monthly obligations details.
    case obligationsDetails
}

// MARK: - Transaction source

/// Identifies which pool of transactions backs a breakdown step card.
enum BreakdownTransactionSource: Hashable {
    /// Spendable income transactions for the current month.
    case income

    /// Active recurring expense streams (obligations / subscriptions / bills).
    case obligations

    /// Variable (non-recurring) expense transactions for the selected period.
    case variableSpend

    /// This month's spend that landed before the selected period began (the "Spent earlier
    /// this month" step). Drills into month-to-date minus the current day/week.
    case priorMonthSpend
}
