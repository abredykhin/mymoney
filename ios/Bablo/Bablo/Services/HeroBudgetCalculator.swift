import Foundation

/// Pure calculation layer for the LiquidHeroView widget.
/// Extracted from the view so the budget math can be unit-tested without SwiftUI.
struct HeroBudgetCalculator {

    // MARK: - Inputs (mirrors the BudgetService @Published values the view reads)

    let monthlyIncome: Double
    let monthlyMandatoryExpenses: Double
    let variableSpend: Double               // current month variable spend (post-filter)
    let previousWeekVariableSpend: Double
    let previousMonthVariableSpend: Double

    // MARK: - Date context (injectable for testing)

    let dayOfMonth: Int          // 1-31: how far into the month are we?
    let daysInMonth: Int         // 28-31

    // MARK: - Derived: discretionary budget for the selected period

    /// Monthly discretionary = income − mandatory expenses, floored to 0.
    var monthlyDiscretionary: Double {
        max(0, monthlyIncome - monthlyMandatoryExpenses)
    }

    /// Weekly discretionary = monthly prorated over 7 days.
    var weeklyDiscretionary: Double {
        guard daysInMonth > 0 else { return 0 }
        return monthlyDiscretionary / Double(daysInMonth) * 7
    }

    /// Daily discretionary = monthly prorated over one day.
    var dailyDiscretionary: Double {
        guard daysInMonth > 0 else { return 0 }
        return monthlyDiscretionary / Double(daysInMonth)
    }

    func totalDiscretionary(for period: HeroPeriod) -> Double {
        switch period {
        case .day:   return dailyDiscretionary
        case .month: return monthlyDiscretionary
        case .week:  return weeklyDiscretionary
        }
    }

    // MARK: - Derived: how much has been spent so far in the period

    /// Monthly: use the actual variable spend from the DB.
    var monthlySpentSoFar: Double { variableSpend }

    /// Weekly: prorate the month-to-date spend over 7 days.
    var weeklySpentSoFar: Double {
        guard dayOfMonth > 0 else { return 0 }
        return (variableSpend / Double(dayOfMonth)) * 7
    }

    /// Daily: average daily spend so far this month.
    var dailySpentSoFar: Double {
        guard dayOfMonth > 0 else { return 0 }
        return variableSpend / Double(dayOfMonth)
    }

    func spentSoFar(for period: HeroPeriod) -> Double {
        switch period {
        case .day:   return dailySpentSoFar
        case .month: return monthlySpentSoFar
        case .week:  return weeklySpentSoFar
        }
    }

    // MARK: - Derived: spendable remaining

    func spendable(for period: HeroPeriod) -> Double {
        max(0, totalDiscretionary(for: period) - spentSoFar(for: period))
    }

    // MARK: - Derived: liquid fill ratio (clamped to [0.02, 1.0])

    func fillTarget(for period: HeroPeriod) -> Double {
        let budget = totalDiscretionary(for: period)
        guard budget > 0 else { return 0.10 }
        let ratio = spendable(for: period) / budget
        // At 0% remaining show a deliberate red pool (10%) rather than an empty gray card.
        return ratio <= 0 ? 0.10 : min(1.0, ratio)
    }

    // MARK: - Derived: delta label vs previous period

    /// Returns "+$42 vs last wk" / "-$12 vs last mo" (nil when no prior data).
    /// Positive delta = spent LESS than the previous period (more money left).
    func deltaLabel(for period: HeroPeriod) -> String? {
        let prev: Double
        let curr: Double
        let suffix: String
        switch period {
        case .day:   return nil
        case .week:
            prev = previousWeekVariableSpend
            curr = weeklySpentSoFar
            suffix = "vs last wk"
        case .month:
            prev = previousMonthVariableSpend
            curr = variableSpend
            suffix = "vs last mo"
        }
        guard prev > 0 || curr > 0 else { return nil }
        let delta = Int((prev - curr).rounded())
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)$\(abs(delta).formatted()) \(suffix)"
    }
}
