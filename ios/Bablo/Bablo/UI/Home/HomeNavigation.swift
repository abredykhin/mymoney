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

    /// Transaction list for one of the breakdown steps.
    case breakdownTransactions(BreakdownTransactionSource, HeroPeriod, String? = nil)

    /// Detail screen for the user's saving streak.
    case streakDetail

    /// The full paginated list of all transactions.
    case allTransactions
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
}
