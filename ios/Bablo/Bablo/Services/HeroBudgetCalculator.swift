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
    let previousDayVariableSpend: Double
    let previousWeekVariableSpend: Double
    let previousMonthVariableSpend: Double

    // MARK: - Date context (injectable for testing)

    let dayOfMonth: Int          // 1-31: how far into the month are we?
    let daysInMonth: Int         // 28-31
    let daysElapsedInWeek: Int   // 1-7: how many days of the current calendar week have elapsed?

    init(
        monthlyIncome: Double,
        monthlyMandatoryExpenses: Double,
        knownIncomeThisMonth: Double,
        extraIncomeThisMonth: Double,
        variableSpend: Double,
        currentWeekVariableSpend: Double,
        todayVariableSpend: Double,
        liquidCashAvailable: Double?,
        spendingPlanMode: SpendingPlanMode,
        upcomingUnpaidExpenses: Double,
        previousDayVariableSpend: Double,
        previousWeekVariableSpend: Double,
        previousMonthVariableSpend: Double,
        dayOfMonth: Int,
        daysInMonth: Int,
        daysElapsedInWeek: Int = 1
    ) {
        self.monthlyIncome = monthlyIncome
        self.monthlyMandatoryExpenses = monthlyMandatoryExpenses
        self.knownIncomeThisMonth = knownIncomeThisMonth
        self.extraIncomeThisMonth = extraIncomeThisMonth
        self.variableSpend = variableSpend
        self.currentWeekVariableSpend = currentWeekVariableSpend
        self.todayVariableSpend = todayVariableSpend
        self.liquidCashAvailable = liquidCashAvailable
        self.spendingPlanMode = spendingPlanMode
        self.upcomingUnpaidExpenses = upcomingUnpaidExpenses
        self.previousDayVariableSpend = previousDayVariableSpend
        self.previousWeekVariableSpend = previousWeekVariableSpend
        self.previousMonthVariableSpend = previousMonthVariableSpend
        self.dayOfMonth = dayOfMonth
        self.daysInMonth = daysInMonth
        self.daysElapsedInWeek = daysElapsedInWeek
    }

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
            // How many days of this week are in the current month?
            // Today is `dayOfMonth`. The week started `daysElapsedInWeek` days ago.
            // So the week covers from `dayOfMonth - (daysElapsedInWeek - 1)` to `dayOfMonth + (7 - daysElapsedInWeek)`.
            // Count how many of these 7 days fall within [1, daysInMonth].
            let weekStartDay = dayOfMonth - (daysElapsedInWeek - 1)
            let weekEndDay = dayOfMonth + (7 - daysElapsedInWeek)
            
            var daysInCurrentMonthThisWeek = 0
            for day in weekStartDay...weekEndDay {
                if day >= 1 && day <= daysInMonth {
                    daysInCurrentMonthThisWeek += 1
                }
            }
            let daysInNextMonthThisWeek = 7 - daysInCurrentMonthThisWeek
            
            // Capped weekly budget baseline before this week's spending started.
            let monthlyRemainingBeforeThisWeek = monthlyDiscretionary - (variableSpend - currentWeekVariableSpend)
            
            // Budget for current month's days of the week: capped by what's left in the month.
            let currentMonthDiscretionaryPart = Double(daysInCurrentMonthThisWeek) * dailyDiscretionary
            let currentMonthBudgetCapped = max(0, min(currentMonthDiscretionaryPart, monthlyRemainingBeforeThisWeek))
            
            // Budget for next month's days of the week: fresh and uncapped discretionary room.
            let nextMonthBudget = Double(daysInNextMonthThisWeek) * dailyDiscretionary
            
            return currentMonthBudgetCapped + nextMonthBudget
            
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
        let rawSpendable = effectiveBudget(for: period) - spentSoFar(for: period)
        
        switch period {
        case .month:
            return rawSpendable
            
        case .week, .day:
            guard spendingPlanMode == .safeToSpend, liquidCashAvailable != nil else {
                return rawSpendable
            }
            
            let safeMonthlyRemaining = spendable(for: .month)
            if safeMonthlyRemaining < 0 {
                return max(rawSpendable, safeMonthlyRemaining)
            } else {
                return rawSpendable
            }
        }
    }

    // MARK: - Derived: effective budget (denominator for "X of Y" display and fill ratio)

    /// Stable budget baseline that does not expand when overspent.
    func effectiveBudget(for period: HeroPeriod) -> Double {
        switch period {
        case .month:
            return budget(for: .month)
            
        case .week, .day:
            let rawBudget = budget(for: period)
            guard spendingPlanMode == .safeToSpend, liquidCashAvailable != nil else {
                return rawBudget
            }
            
            // Remaining monthly budget before this period's spending started.
            let monthlyRemainingBeforePeriod = spendable(for: .month) + spentSoFar(for: period)
            return max(0, min(rawBudget, monthlyRemainingBeforePeriod))
        }
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
        guard budget(for: period) > 0 else { return nil }

        let prev: Double
        let curr: Double
        let suffix: String
        switch period {
        case .day:
            prev = previousDayVariableSpend
            curr = todayVariableSpend
            suffix = "vs yesterday"
        case .week:
            prev = previousWeekVariableSpend
            curr = currentWeekVariableSpend   // actual this-week spend, not MTD proration
            suffix = "vs last wk"
        case .month:
            prev = previousMonthVariableSpend
            curr = variableSpend
            suffix = "vs last mo"
        }
        // Show the chip when either side has real spending to compare.
        // Budget/income availability should not suppress a period-over-period spend delta.
        guard prev > 0 || curr > 0 else { return nil }
        let delta = Int((prev - curr).rounded())
        guard abs(delta) >= 1 else { return nil }
        if spendable(for: period) < 0 {
            let amount = "$\(compactDollar(abs(delta)))"
            return delta >= 0 ? "\(amount) less in the red \(suffix)" : "\(amount) deeper in the red \(suffix)"
        }
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

// MARK: - Mandatory stream row for the obligations step

struct HeroBudgetMandatoryRow: Identifiable, Equatable {
    var id: Int
    let name: String
    let monthlyAmount: Double
    let averageAmount: Double
    let frequency: String
    let isUpcoming: Bool
    let frequencyDisplay: String
}

// MARK: - Money left breakdown

struct HeroBudgetBreakdownCalculator {
    let calculator: HeroBudgetCalculator
    let period: HeroPeriod

    var finalAmount: Double {
        calculator.spendable(for: period)
    }

    var reconciledAmount: Double {
        steps.reduce(0) { $0 + $1.amount }
    }

    /// True when the liquid-cash safety cap is tighter than the income-based discretionary budget.
    var isCashCapped: Bool {
        guard calculator.spendingPlanMode == .safeToSpend,
              let liquid = calculator.liquidCashAvailable else { return false }
        let safeCash = max(0, liquid - calculator.upcomingUnpaidExpenses)
        return (safeCash + calculator.monthlySpentSoFar) < calculator.monthlyDiscretionary
    }

    /// Step number that contains the variable-spending rows (always the last step).
    var spendStepNumber: Int { mandatoryStepNumber != nil ? 3 : 2 }

    /// Step number for the monthly obligations rows, or nil when there is no such step.
    var mandatoryStepNumber: Int? {
        guard period == .month, !isCashCapped,
              calculator.monthlyMandatoryExpenses > 0 else { return nil }
        return 2
    }

    var steps: [HeroBudgetBreakdownStep] {
        switch period {
        case .month:
            return isCashCapped ? cashCappedMonthlySteps : incomeMonthlySteps
        case .week, .day:
            return periodSteps
        }
    }

    // Monthly income-based flow: income → obligations → spending = what's left
    private var incomeMonthlySteps: [HeroBudgetBreakdownStep] {
        var result: [HeroBudgetBreakdownStep] = []
        var running = 0.0

        let inc = calculator.effectiveIncome
        running += inc
        result.append(HeroBudgetBreakdownStep(
            number: 1,
            title: "Income this month",
            amount: inc,
            afterAmount: running,
            tone: .positive,
            transactionSource: .income
        ))

        if calculator.monthlyMandatoryExpenses > 0 {
            let mandatory = -calculator.monthlyMandatoryExpenses
            running += mandatory
            result.append(HeroBudgetBreakdownStep(
                number: 2,
                title: "Monthly obligations",
                amount: mandatory,
                afterAmount: running,
                tone: .negative,
                transactionSource: .obligations
            ))
        }

        result.append(HeroBudgetBreakdownStep(
            number: result.count + 1,
            title: "What you've spent this month",
            amount: -calculator.monthlySpentSoFar,
            afterAmount: finalAmount,
            tone: .negative,
            transactionSource: .variableSpend
        ))

        return result
    }

    // Monthly cash-capped flow: safe budget → spending = what's left
    private var cashCappedMonthlySteps: [HeroBudgetBreakdownStep] {
        [
            HeroBudgetBreakdownStep(
                number: 1,
                title: "Start with safe cash",
                amount: calculator.effectiveBudget(for: .month),
                afterAmount: calculator.effectiveBudget(for: .month),
                tone: .positive,
                transactionSource: nil     // calculated cap, not a transaction set
            ),
            HeroBudgetBreakdownStep(
                number: 2,
                title: "What you've spent this month",
                amount: -calculator.monthlySpentSoFar,
                afterAmount: finalAmount,
                tone: .negative,
                transactionSource: .variableSpend
            )
        ]
    }

    // Week / day flow
    private var periodSteps: [HeroBudgetBreakdownStep] {
        let budget = calculator.effectiveBudget(for: period)
        let spent = calculator.spentSoFar(for: period)
        
        return [
            HeroBudgetBreakdownStep(
                number: 1,
                title: startingStepTitle,
                amount: budget,
                afterAmount: budget,
                tone: .positive,
                transactionSource: nil     // prorated budget number, no transactions
            ),
            HeroBudgetBreakdownStep(
                number: 2,
                title: burnedStepTitle,
                amount: -spent,
                afterAmount: budget - spent,
                tone: .negative,
                transactionSource: .variableSpend
            )
        ]
    }

    // Context rows are only used for week/day to show the monthly cap.
    // Monthly steps are self-explanatory and need no additional context rows.
    var contextRows: [HeroBudgetContextRow] {
        guard period != .month else { return [] }

        return [
            HeroBudgetContextRow(
                title: "Monthly room left",
                detail: "Caps this period when the month is tighter",
                amount: calculator.monthlySpendable
            )
        ]
    }

    static func accountAuditRows(accounts: [HeroBudgetAccountInput]) -> HeroBudgetAccountAuditRows {
        let counted = accounts.compactMap { account -> HeroBudgetAccountAuditRow? in
            switch account.type.lowercased() {
            case "depository":
                return HeroBudgetAccountAuditRow(
                    name: account.name,
                    detail: account.mask.map { "••\($0)" } ?? "Cash account",
                    amount: account.currentBalance,
                    isCounted: true
                )
            case "credit":
                return HeroBudgetAccountAuditRow(
                    name: account.name,
                    detail: account.mask.map { "••\($0)" } ?? "Credit balance",
                    amount: -account.currentBalance,
                    isCounted: true
                )
            default:
                return nil
            }
        }

        return HeroBudgetAccountAuditRows(counted: counted, notCounted: [])
    }

    private var startingStepTitle: String {
        switch period {
        case .day:   return "Start with today's room"
        case .week:  return "Start with this week's room"
        case .month: return "Start with safe cash"
        }
    }

    private var burnedStepTitle: String {
        switch period {
        case .day:   return "What you've spent today"
        case .week:  return "What you've spent this week"
        case .month: return "What you've spent this month"
        }
    }

}

struct HeroBudgetBreakdownStep: Identifiable, Equatable {
    enum Tone: Equatable {
        case positive
        case neutral
        case negative
    }

    var id: Int { number }
    let number: Int
    let title: String
    let amount: Double
    let afterAmount: Double
    let tone: Tone
    /// Which pool of transactions this step links to. `nil` means the step is
    /// a calculated number with no drillable transactions (e.g. "Start with safe cash").
    let transactionSource: BreakdownTransactionSource?
}

struct HeroBudgetContextRow: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let detail: String
    let amount: Double
}

struct HeroBudgetAccountInput: Equatable {
    let name: String
    let mask: String?
    let type: String
    let currentBalance: Double
}

struct HeroBudgetAccountAuditRows: Equatable {
    let counted: [HeroBudgetAccountAuditRow]
    let notCounted: [HeroBudgetAccountAuditRow]

    var countedTotal: Double {
        counted.reduce(0) { $0 + $1.amount }
    }
}

struct HeroBudgetAccountAuditRow: Identifiable, Equatable {
    var id: String { "\(name)-\(detail)-\(amount)" }
    let name: String
    let detail: String
    let amount: Double
    let isCounted: Bool

    var displayAmount: String {
        let rounded = Int(amount.rounded())
        if rounded < 0 {
            return "-$\(abs(rounded).formatted())"
        }
        return "$\(rounded.formatted())"
    }
}

struct HeroCushionSnapshot: Equatable {
    let period: HeroPeriod
    let currentRoom: Double
    let previousRoom: Double
    let roomDelta: Double
    let currentSpend: Double
    let previousSpend: Double

    init?(calculator: HeroBudgetCalculator, period: HeroPeriod) {
        guard calculator.budget(for: period) > 0 else { return nil }

        let previousSpend: Double
        let currentSpend: Double

        switch period {
        case .day:
            previousSpend = calculator.previousDayVariableSpend
            currentSpend = calculator.todayVariableSpend
        case .week:
            previousSpend = calculator.previousWeekVariableSpend
            currentSpend = calculator.currentWeekVariableSpend
        case .month:
            previousSpend = calculator.previousMonthVariableSpend
            currentSpend = calculator.variableSpend
        }

        guard previousSpend > 0 || currentSpend > 0 else { return nil }

        let delta = (previousSpend - currentSpend).rounded()
        guard abs(delta) >= 1 else { return nil }

        self.period = period
        self.currentSpend = currentSpend
        self.previousSpend = previousSpend
        self.currentRoom = calculator.spendable(for: period)
        self.roomDelta = delta
        self.previousRoom = self.currentRoom - delta
    }

    var hasMoreRoom: Bool {
        roomDelta >= 0
    }
}

struct HeroCushionDriver: Equatable, Identifiable {
    enum Kind: Equatable {
        case grew
        case shrank
    }

    var id: String { bucket.id }
    let bucket: SpendingBucket
    let currentAmount: Double
    let previousAmount: Double
    let transactionCount: Int
    let roomDelta: Double

    var kind: Kind {
        roomDelta >= 0 ? .grew : .shrank
    }

    static func drivers(from items: [CategoryBreakdownItem], limit: Int = 5) -> [HeroCushionDriver] {
        items.compactMap { item in
            guard let previousAmount = item.previousAmount else { return nil }
            let delta = (previousAmount - item.totalAmount).rounded()
            guard abs(delta) >= 1 else { return nil }
            return HeroCushionDriver(
                bucket: item.bucket,
                currentAmount: item.totalAmount,
                previousAmount: previousAmount,
                transactionCount: item.transactionCount,
                roomDelta: delta
            )
        }
        .sorted { abs($0.roomDelta) > abs($1.roomDelta) }
        .prefix(limit)
        .map { $0 }
    }
}
