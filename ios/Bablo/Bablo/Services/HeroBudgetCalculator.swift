import Foundation

/// Pure calculation layer for the LiquidHeroView widget.
/// Extracted from the view so the budget math can be unit-tested without SwiftUI.
struct HeroBudgetCalculator {

    // MARK: - Inputs (mirrors the BudgetService @Published values the view reads)

    let monthlyIncome: Double
    let monthlyMandatoryExpenses: Double
    let knownIncomeThisMonth: Double
    let extraIncomeThisMonth: Double
    let variableSpend: Double               // month-to-date variable spend
    let currentWeekVariableSpend: Double    // actual spend in the current calendar week
    let todayVariableSpend: Double          // actual spend so far today
    let liquidCashAvailable: Double?
    let spendingPlanMode: SpendingPlanMode
    let upcomingUnpaidExpenses: Double
    let previousWeekVariableSpend: Double
    let previousMonthVariableSpend: Double

    // MARK: - Date context (injectable for testing)

    let dayOfMonth: Int          // 1-31: how far into the month are we?
    let daysInMonth: Int         // 28-31

    // MARK: - Derived: discretionary budget for the selected period

    /// Monthly discretionary = income − mandatory expenses, floored to 0.
    var monthlyDiscretionary: Double {
        max(0, effectiveIncome - monthlyMandatoryExpenses)
    }

    var effectiveIncome: Double {
        // Edge Case D: The Paycheck Illusion
        // If no paycheck has landed yet (knownIncomeThisMonth < 30% of expected) and the user has linked
        // bank accounts (liquidCashAvailable != nil), expected monthlyIncome is decayed linearly
        // from Day 15 down to 0 at month-end to prevent overspending on unreceived salary.
        // Once any actual paycheck lands (knownIncomeThisMonth >= 30%), no decay applies.
        let expected: Double
        let salaryThreshold = monthlyIncome * 0.30
        if knownIncomeThisMonth < salaryThreshold, liquidCashAvailable != nil, dayOfMonth > 15 {
            let totalDays = Double(daysInMonth)
            let currentDay = Double(dayOfMonth)
            let gracePeriod = 15.0
            let decayFactor = max(0.0, 1.0 - (currentDay - gracePeriod) / (totalDays - gracePeriod))
            expected = monthlyIncome * decayFactor
        } else {
            expected = monthlyIncome
        }
        return max(expected, knownIncomeThisMonth) + extraIncomeThisMonth
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

    /// Monthly: actual month-to-date variable spend from the DB.
    var monthlySpentSoFar: Double { variableSpend }

    /// Weekly: actual spend in the current calendar week (Mon–today).
    var weeklySpentSoFar: Double { currentWeekVariableSpend }

    /// Daily: actual spend recorded so far today.
    var dailySpentSoFar: Double { todayVariableSpend }

    func spentSoFar(for period: HeroPeriod) -> Double {
        switch period {
        case .day:   return dailySpentSoFar
        case .month: return monthlySpentSoFar
        case .week:  return weeklySpentSoFar
        }
    }

    // MARK: - Derived: budget baseline (stable denominator for "X of Y" display)

    func budget(for period: HeroPeriod) -> Double {
        switch period {
        case .month:
            guard spendingPlanMode == .safeToSpend, let liquidCashAvailable else {
                return monthlyDiscretionary
            }
            // For monthly, the baseline budget is capped by the safe cash available before MTD spending.
            // safeCash is net liquid cash minus upcoming unpaid mandatory bills in this month.
            let safeCash = max(0, liquidCashAvailable - upcomingUnpaidExpenses)
            return max(0, min(monthlyDiscretionary, safeCash + variableSpend))
            
        case .week:
            // Capped weekly budget baseline before this week's spending started.
            let monthlyRemainingBeforeThisWeek = monthlyDiscretionary - (variableSpend - currentWeekVariableSpend)
            return max(0, min(weeklyDiscretionary, monthlyRemainingBeforeThisWeek))
            
        case .day:
            // Daily budget = weekly budget / 7.
            // Spending within this allowance each day for a full week exactly hits the weekly budget,
            // answering "what can I safely spend today without blowing the week?"
            return budget(for: .week) / 7
        }
    }

    // MARK: - Derived: monthly remaining (used as a cap for sub-month periods)

    /// How much of the monthly discretionary budget is still available.
    var monthlySpendable: Double {
        max(0, monthlyDiscretionary - monthlySpentSoFar)
    }

    // MARK: - Derived: spendable remaining

    func spendable(for period: HeroPeriod) -> Double {
        let planRemaining = budget(for: period) - spentSoFar(for: period)

        switch period {
        case .month:
            guard spendingPlanMode == .safeToSpend, let liquidCashAvailable else {
                return planRemaining
            }
            // Monthly budget is already capped by initial cash, so planRemaining is safe.
            return planRemaining

        case .week, .day:
            guard spendingPlanMode == .safeToSpend, let liquidCashAvailable else {
                return planRemaining
            }
            // Under Safe-to-Spend, never show a weekly or daily discretionary budget
            // that exceeds the actual total liquid cash available for the month.
            let safeMonthlyRemaining = spendable(for: .month)
            return max(0, min(planRemaining, safeMonthlyRemaining))
        }
    }

    // MARK: - Derived: effective budget (denominator for "X of Y" display and fill ratio)

    /// Stable budget baseline that does not expand when overspent.
    func effectiveBudget(for period: HeroPeriod) -> Double {
        budget(for: period)
    }

    // MARK: - Derived: liquid fill ratio (clamped to [0.10, 1.0])

    func fillTarget(for period: HeroPeriod) -> Double {
        let budget = effectiveBudget(for: period)
        guard budget > 0 else { return 0.10 }
        let ratio = spendable(for: period) / budget
        // At 0% remaining show a deliberate red pool (10%) rather than an empty gray card.
        return ratio <= 0 ? 0.10 : min(1.0, ratio)
    }

    // MARK: - Derived: delta label vs previous period

    /// Returns "+$42 vs last wk" / "-$12 vs last mo" (nil when no prior data).
    /// Positive delta = MORE left than at this point last period (currentSpendable > previousSpendable).
    /// Since both spendables share the same budget denominator the arithmetic reduces to
    /// previousSpend − currentSpend, which is what the implementation computes.
    func deltaLabel(for period: HeroPeriod) -> String? {
        let prev: Double
        let curr: Double
        let suffix: String
        switch period {
        case .day:   return nil
        case .week:
            prev = previousWeekVariableSpend
            curr = currentWeekVariableSpend   // actual this-week spend, not MTD proration
            suffix = "vs last wk"
        case .month:
            prev = previousMonthVariableSpend
            curr = variableSpend
            suffix = "vs last mo"
        }
        // Show delta only when there is effective income to provide context,
        // and when the current period has real spending to compare.
        guard effectiveIncome > 0 else { return nil }
        guard curr > 0 else { return nil }
        // Only compare against a previous period that was within budget.
        // If last period's spending exceeded the discretionary budget, it contained
        // extraordinary expenses (e.g. one-time legal fees) that sit outside the
        // discretionary framework — projecting them in would produce a fictional
        // "remaining" figure for last period and a misleading delta.
        let periodBudget: Double
        switch period {
        case .week:  periodBudget = weeklyDiscretionary
        case .month: periodBudget = monthlyDiscretionary
        case .day:   periodBudget = dailyDiscretionary
        }
        guard prev <= periodBudget else { return nil }
        let delta = Int((prev - curr).rounded())
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)$\(compactDollar(abs(delta))) \(suffix)"
    }

    // MARK: - Formatting helpers

    /// Compact dollar string: exact below $1 K, "2.6K" / "26K" at higher amounts.
    private func compactDollar(_ n: Int) -> String {
        guard n >= 1_000 else { return n.formatted() }
        let k = Double(n) / 1_000
        if k >= 10 { return "\(Int(k.rounded()))K" }
        let tenths = Int((k * 10).rounded())
        return tenths % 10 == 0 ? "\(tenths / 10)K" : "\(tenths / 10).\(tenths % 10)K"
    }
}
