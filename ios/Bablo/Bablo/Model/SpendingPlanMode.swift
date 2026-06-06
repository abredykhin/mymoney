import Foundation

enum SpendingPlanMode: String, Codable, CaseIterable, Equatable {
    case safeToSpend = "safe_to_spend"
    case monthlyPlan = "monthly_plan"

    var displayName: String {
        switch self {
        case .safeToSpend:
            return "Safe to Spend"
        case .monthlyPlan:
            return "Monthly Plan"
        }
    }
}

/// Controls how the budget pool total is derived in `get_budget_state`.
///
/// - `projected`: income-discretionary model (default).
///   pool_total = max(0, effectiveIncome − mandatory − goals)
/// - `cashOnly`: cash-balance model.
///   pool_total = max(0, netCash − upcomingBills − goals)
enum IncomeBasis: String, Codable, CaseIterable, Equatable {
    case projected = "projected"
    case cashOnly  = "cash_only"

    var displayName: String {
        switch self {
        case .projected: return "Income-based"
        case .cashOnly:  return "Cash balance"
        }
    }
}

struct SpendingPlanModeStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func mode(for userId: String) -> SpendingPlanMode {
        guard let rawValue = defaults.string(forKey: key(for: userId)) else {
            return .safeToSpend
        }
        return SpendingPlanMode(rawValue: rawValue) ?? .safeToSpend
    }

    func save(_ mode: SpendingPlanMode, for userId: String) {
        defaults.set(mode.rawValue, forKey: key(for: userId))
    }

    private func key(for userId: String) -> String {
        "spendingPlanMode.\(userId)"
    }
}
