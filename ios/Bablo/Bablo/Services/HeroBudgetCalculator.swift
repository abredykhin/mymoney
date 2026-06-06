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

    let budgetState: BudgetStateRow

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
        daysElapsedInWeek: Int = 1,
        incomeBasis: IncomeBasis? = nil,
        budgetState: BudgetStateRow? = nil
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

        if let budgetState = budgetState {
            self.budgetState = budgetState
        } else {
            // Synthesize BudgetStateRow using the inputs
            let salaryThreshold = monthlyIncome * 0.30
            let expectedIncome: Double
            if knownIncomeThisMonth < salaryThreshold, liquidCashAvailable != nil, dayOfMonth > 15 {
                let totalDays = Double(daysInMonth)
                let currentDay = Double(dayOfMonth)
                let gracePeriod = 15.0
                let decayFactor = max(0.0, 1.0 - (currentDay - gracePeriod) / (totalDays - gracePeriod))
                expectedIncome = monthlyIncome * decayFactor
            } else {
                expectedIncome = monthlyIncome
            }
            let effIncome = max(expectedIncome, knownIncomeThisMonth) + extraIncomeThisMonth

            // The pool model is driven by income_basis (the RPC's source of truth).
            // When no basis is supplied (the synthesize-only fallback used before the
            // RPC has loaded, and in unit tests), map the legacy spending_plan_mode:
            // safeToSpend → cash_only, monthlyPlan → projected.
            let resolvedBasis = incomeBasis
                ?? (spendingPlanMode == .safeToSpend ? .cashOnly : .projected)

            let poolTotalVal: Double
            let poolRemainingVal: Double
            if resolvedBasis == .cashOnly {
                poolTotalVal = max(0.0, (liquidCashAvailable ?? 0.0) - upcomingUnpaidExpenses)
                poolRemainingVal = poolTotalVal
            } else {
                poolTotalVal = max(0.0, effIncome - monthlyMandatoryExpenses)
                poolRemainingVal = poolTotalVal - variableSpend
            }

            let daysRemaining = daysInMonth - dayOfMonth + 1
            let dailyPaceVal = max(0.0, poolRemainingVal) / Double(max(1, daysRemaining))
            let weeklyPaceVal = min(max(0.0, poolRemainingVal), dailyPaceVal * 7.0)

            self.budgetState = BudgetStateRow(
                poolTotal: poolTotalVal,
                poolRemaining: poolRemainingVal,
                dailyPace: dailyPaceVal,
                weeklyPace: weeklyPaceVal,
                spentToday: todayVariableSpend,
                spentWeek: currentWeekVariableSpend,
                spentMtd: variableSpend,
                prevDaySpent: previousDayVariableSpend,
                prevWeekSpent: previousWeekVariableSpend,
                prevMonthSpent: previousMonthVariableSpend,
                effectiveIncome: effIncome,
                mandatory: monthlyMandatoryExpenses,
                goalsSetAside: 0.0,
                netCash: liquidCashAvailable ?? 0.0,
                upcomingBills: upcomingUnpaidExpenses,
                incomeBasis: resolvedBasis,
                daysInMonth: daysInMonth,
                daysRemaining: daysRemaining,
                daysElapsedInWeek: daysElapsedInWeek,
                knownIncome: knownIncomeThisMonth,
                extraIncome: extraIncomeThisMonth
            )
        }
    }

    init(budgetState: BudgetStateRow, spendingPlanMode: SpendingPlanMode) {
        self.budgetState = budgetState
        self.spendingPlanMode = spendingPlanMode

        self.monthlyIncome = budgetState.effectiveIncome
        self.monthlyMandatoryExpenses = budgetState.mandatory
        self.knownIncomeThisMonth = budgetState.knownIncome
        self.extraIncomeThisMonth = budgetState.extraIncome
        self.variableSpend = budgetState.spentMtd
        self.currentWeekVariableSpend = budgetState.spentWeek
        self.todayVariableSpend = budgetState.spentToday
        self.liquidCashAvailable = budgetState.netCash
        self.upcomingUnpaidExpenses = 0.0
        self.previousDayVariableSpend = budgetState.prevDaySpent
        self.previousWeekVariableSpend = budgetState.prevWeekSpent
        self.previousMonthVariableSpend = budgetState.prevMonthSpent
        self.dayOfMonth = budgetState.daysInMonth - budgetState.daysRemaining + 1
        self.daysInMonth = budgetState.daysInMonth
        self.daysElapsedInWeek = budgetState.daysElapsedInWeek
    }

    // MARK: - Derived: discretionary budget for the selected period

    /// Monthly discretionary = income − mandatory expenses, floored to 0.
    var monthlyDiscretionary: Double {
        max(0, effectiveIncome - monthlyMandatoryExpenses)
    }

    /// Expected gross income for the month after the late-month decay guard (Edge Case D).
    var expectedMonthlyIncome: Double {
        let salaryThreshold = monthlyIncome * 0.30
        guard knownIncomeThisMonth < salaryThreshold, liquidCashAvailable != nil, dayOfMonth > 15 else {
            return monthlyIncome
        }
        let totalDays = Double(daysInMonth)
        let currentDay = Double(dayOfMonth)
        let gracePeriod = 15.0
        let decayFactor = max(0.0, 1.0 - (currentDay - gracePeriod) / (totalDays - gracePeriod))
        return monthlyIncome * decayFactor
    }

    var effectiveIncome: Double {
        budgetState.effectiveIncome
    }

    /// Which pool model produced these numbers — the single source of truth for
    /// the "How we got this" breakdown (cash vs income). Mirrors what the RPC used,
    /// so the steps always reconcile with the headline.
    var incomeBasis: IncomeBasis {
        budgetState.incomeBasis
    }

    /// The single-pool pace for a period given a remaining pool value. Identical to
    /// the formula the RPC uses for daily/weekly pace, so `pace(period, poolRemaining)`
    /// equals the hero's `spendable(period)`. Used to compute the previous-period room
    /// for the cushion without mixing spend-scale and pace-scale numbers.
    func pace(for period: HeroPeriod, remaining: Double) -> Double {
        let drem = Double(max(1, budgetState.daysRemaining))
        switch period {
        case .month: return remaining
        case .day:   return max(0, remaining) / drem
        case .week:  return min(max(0, remaining), max(0, remaining) / drem * 7)
        }
    }

    /// Like `pace`, but does not floor at 0. Used by the Cushion to show "Deeper in the red"
    /// when the user is overspent.
    func unflooredPace(for period: HeroPeriod, remaining: Double) -> Double {
        let drem = Double(max(1, budgetState.daysRemaining))
        switch period {
        case .month: 
            return remaining
        case .day:   
            return remaining / drem
        case .week:  
            let unflooredDaily = remaining / drem
            let unflooredWeekly = unflooredDaily * 7.0
            if remaining >= 0 {
                return min(remaining, unflooredWeekly)
            } else {
                return max(remaining, unflooredWeekly)
            }
        }
    }

    /// Projected income not yet received this month — the "Expected paycheck" row in the
    /// Money-Left breakdown. effectiveIncome already folds in BOTH received recurring income
    /// (known) and received one-off income (extra), so subtract both; otherwise a one-off
    /// inflow (e.g. a brokerage credit counted as extra income) is double-counted — once as a
    /// received income row and again inside this figure — inflating it and breaking the
    /// breakdown's reconciliation to effectiveIncome.
    var expectedIncomeStillToCome: Double {
        max(0.0, effectiveIncome - knownIncomeThisMonth - extraIncomeThisMonth)
    }



    func totalDiscretionary(for period: HeroPeriod) -> Double {
        switch period {
        case .day:   return budgetState.poolTotal / Double(max(1, budgetState.daysInMonth))
        case .week:  return budgetState.poolTotal / Double(max(1, budgetState.daysInMonth)) * 7
        case .month: return budgetState.poolTotal
        }
    }

    // MARK: - Derived: how much has been spent so far in the period

    var monthlySpentSoFar: Double { budgetState.spentMtd }
    var weeklySpentSoFar: Double { budgetState.spentWeek }
    var dailySpentSoFar: Double { budgetState.spentToday }

    func spentSoFar(for period: HeroPeriod) -> Double {
        switch period {
        case .day:   return dailySpentSoFar
        case .week:  return weeklySpentSoFar
        case .month: return monthlySpentSoFar
        }
    }

    // MARK: - Derived: budget baseline (stable denominator for "X of Y" display)

    func budget(for period: HeroPeriod) -> Double {
        effectiveBudget(for: period)
    }

    // MARK: - Derived: monthly remaining (used as a cap for sub-month periods)

    var monthlySpendable: Double {
        budgetState.poolRemaining
    }

    // MARK: - Derived: spendable remaining

    func spendable(for period: HeroPeriod) -> Double {
        switch period {
        case .day:   return budgetState.dailyPace
        case .week:  return budgetState.weeklyPace
        case .month: return budgetState.poolRemaining
        }
    }

    // MARK: - Derived: effective budget (denominator for "X of Y" display and fill ratio)

    func effectiveBudget(for period: HeroPeriod) -> Double {
        switch period {
        case .month:
            return budgetState.poolTotal
        case .week:
            return budgetState.poolTotal / Double(max(1, budgetState.daysInMonth)) * 7
        case .day:
            return budgetState.poolTotal / Double(max(1, budgetState.daysInMonth))
        }
    }

    // MARK: - Derived: liquid fill ratio (clamped to [0.10, 1.0])

    /// The period's own budget for badge/fill.
    /// - Month: the month pool (`effectiveBudget`) — unchanged, and correct in both income and
    ///   cash modes (cash mode's remaining isn't net of spend, so spent+remaining would overstate).
    /// - Day/week: what you've already spent this period plus what's still safe to spend, so it
    ///   resets per period — a fresh day with nothing spent reads as 100% full rather than
    ///   carrying a fraction over from earlier in the month.
    func periodBudget(for period: HeroPeriod) -> Double {
        switch period {
        case .month:       return effectiveBudget(for: .month)
        case .day, .week:  return spentSoFar(for: period) + spendable(for: period)
        }
    }

    func fillTarget(for period: HeroPeriod) -> Double {
        let budget = periodBudget(for: period)
        guard budget > 0 else { return 0.10 }
        let ratio = spendable(for: period) / budget
        return ratio <= 0 ? 0.10 : min(1.0, ratio)
    }

    // MARK: - Derived: delta label vs previous period

    func deltaChip(for period: HeroPeriod) -> HeroDeltaChip? {
        guard let snapshot = HeroCushionSnapshot(calculator: self, period: period) else { return nil }
        let delta = Int(snapshot.roomDelta.rounded())
        // Spending essentially matched the prior period — hide the pill entirely rather than
        // surface a noisy "about the same" chip.
        guard abs(delta) >= 1 else { return nil }

        let suffix: String
        switch period {
        case .day:   suffix = "vs yesterday"
        case .week:  suffix = "vs last wk"
        case .month: suffix = "vs last mo"
        }

        let amount = "$\(compactDollar(abs(delta)))"
        if spendable(for: period) < 0 {
            return HeroDeltaChip(
                label: delta >= 0 ? "\(amount) less in the red \(suffix)" : "\(amount) deeper in the red \(suffix)",
                hasMoreRoom: delta >= 0
            )
        }

        return HeroDeltaChip(
            label: "\(amount) \(delta >= 0 ? "more" : "less") \(suffix)",
            hasMoreRoom: delta >= 0
        )
    }

    func deltaLabel(for period: HeroPeriod) -> String? {
        // The chip mirrors the cushion sheet it opens: both read the single-pool,
        // pace-based room delta from HeroCushionSnapshot. Raw day-over-day spend would let a
        // one-off lump (e.g. a spousal-support wire — legitimate spend that stays counted)
        // read as "+$5K" next to a $40 daily pace and contradict the sheet's "+$40". For
        // .month the pace is 1:1, so this still equals the month-over-month spend delta.
        deltaChip(for: period)?.label
    }

    // MARK: - Formatting helpers

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

    var isCashCapped: Bool {
        false
    }

    var spendStepNumber: Int {
        switch period {
        case .month:
            if calculator.monthlyMandatoryExpenses > 0 {
                return 4
            } else {
                return 3
            }
        case .week, .day:
            // The period breakdown is month-derived (see periodSteps); the spend step is the
            // month's spend (step 2), tappable to the month list but with no inline sub-rows.
            return 0
        }
    }

    var mandatoryStepNumber: Int? {
        guard period == .month, calculator.monthlyMandatoryExpenses > 0 else { return nil }
        return 2
    }

    var steps: [HeroBudgetBreakdownStep] {
        switch period {
        case .month:
            return monthlySteps
        case .week, .day:
            return periodSteps
        }
    }

    private var monthlySteps: [HeroBudgetBreakdownStep] {
        var result: [HeroBudgetBreakdownStep] = []
        var running = 0.0

        if calculator.incomeBasis == .cashOnly {
            let cash = calculator.budgetState.netCash
            running += cash
            result.append(HeroBudgetBreakdownStep(
                number: 1,
                title: "Net cash on hand",
                amount: cash,
                afterAmount: running,
                tone: .positive,
                transactionSource: nil
            ))

            let upcoming = -calculator.budgetState.upcomingBills
            running += upcoming
            result.append(HeroBudgetBreakdownStep(
                number: 2,
                title: "Upcoming bills",
                amount: upcoming,
                afterAmount: running,
                tone: .negative,
                transactionSource: .obligations
            ))

            let goals = -calculator.budgetState.goalsSetAside
            running += goals
            result.append(HeroBudgetBreakdownStep(
                number: 3,
                title: "Goals set aside",
                amount: goals,
                afterAmount: running,
                tone: .neutral,
                transactionSource: nil
            ))

            // Floor the running total if it went negative, matching the pool remaining floor of 0.
            if running < 0 {
                let floorAdjust = -running
                running = 0.0
                result.append(HeroBudgetBreakdownStep(
                    number: result.count + 1,
                    title: "Floor adjustment",
                    amount: floorAdjust,
                    afterAmount: running,
                    tone: .positive,
                    transactionSource: nil
                ))
            }
        } else {
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

            let goals = -calculator.budgetState.goalsSetAside
            running += goals
            result.append(HeroBudgetBreakdownStep(
                number: result.count + 1,
                title: "Goals set aside",
                amount: goals,
                afterAmount: running,
                tone: .neutral,
                transactionSource: nil
            ))

            let spent = -calculator.spentSoFar(for: .month)
            running += spent
            result.append(HeroBudgetBreakdownStep(
                number: result.count + 1,
                title: "What you've spent this month",
                amount: spent,
                afterAmount: calculator.spendable(for: .month),
                tone: .negative,
                transactionSource: .variableSpend
            ))
        }

        return result
    }

    /// Day/week are derived from the month so the period number is unambiguous: start from the
    /// month's budget, subtract what's been spent this month to land on what's left this month
    /// (the hero's "left this month"), then set aside the part reserved for the rest of the
    /// month — what remains is this period's slice (the hero number). Every line is a distinct,
    /// real number and the chain reconciles to the headline pace by construction.
    private var periodSteps: [HeroBudgetBreakdownStep] {
        let monthBudget = calculator.effectiveBudget(for: .month)   // month pool (income or cash)
        let monthLeft = calculator.spendable(for: .month)           // what's left this month
        let pace = calculator.spendable(for: period)                // = final (left this period)
        let setAside = pace - monthLeft                             // ≤ 0: held for the other days

        var steps: [HeroBudgetBreakdownStep] = [
            HeroBudgetBreakdownStep(
                number: 1,
                title: "This month's budget",
                amount: monthBudget,
                afterAmount: monthBudget,
                tone: .positive,
                transactionSource: nil
            )
        ]

        // Income/projected mode subtracts month-to-date spend to reach "left this month"; cash
        // mode's pool is cash-on-hand and does not net spend, so it skips this step (matching
        // the month breakdown, which has no spend step in cash mode).
        if calculator.incomeBasis != .cashOnly {
            let monthSpent = calculator.spentSoFar(for: .month)
            steps.append(
                HeroBudgetBreakdownStep(
                    number: 2,
                    title: "What you've spent this month",
                    amount: -monthSpent,
                    afterAmount: monthLeft,
                    tone: .negative,
                    transactionSource: .variableSpend
                )
            )
        }

        steps.append(
            HeroBudgetBreakdownStep(
                number: steps.count + 1,
                title: "Set aside for the rest of the month",
                amount: setAside,
                afterAmount: pace,
                tone: .neutral,
                transactionSource: nil
            )
        )
        return steps
    }

    /// No longer used by day/week (the month-derived steps tell the whole story), kept empty so
    /// the breakdown view's context-row slot renders nothing.
    var contextRows: [HeroBudgetContextRow] {
        []
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

struct HeroDeltaChip: Equatable {
    let label: String
    let hasMoreRoom: Bool
}

struct HeroCushionSnapshot: Equatable {
    let period: HeroPeriod
    let currentRoom: Double
    let previousRoom: Double
    let roomDelta: Double
    let currentSpend: Double
    let previousSpend: Double
    /// Factor that converts a category's raw spend delta into its impact on this period's
    /// room (pace). 1.0 for month (pool moves 1:1 with spend); ~1/daysRemaining for day;
    /// ~7/daysRemaining for week. Keeps the driver bars in the same units as `roomDelta`
    /// so they bridge `previousRoom → currentRoom` instead of dwarfing the gap.
    let roomScale: Double

    init?(calculator: HeroBudgetCalculator, period: HeroPeriod) {
        guard calculator.effectiveBudget(for: period) > 0 else { return nil }

        let previousSpend: Double
        let currentSpend: Double

        switch period {
        case .day:
            previousSpend = calculator.budgetState.prevDaySpent
            currentSpend = calculator.budgetState.spentToday
        case .week:
            previousSpend = calculator.budgetState.prevWeekSpent
            currentSpend = calculator.budgetState.spentWeek
        case .month:
            previousSpend = calculator.budgetState.prevMonthSpent
            currentSpend = calculator.variableSpend
        }

        guard previousSpend > 0 || currentSpend > 0 else { return nil }

        // Visibility guard (unchanged): show the cushion when spending moved
        // meaningfully period-over-period.
        let displayedPreviousSpend = previousSpend.rounded()
        let displayedCurrentSpend = currentSpend.rounded()
        guard abs(displayedPreviousSpend - displayedCurrentSpend) >= 1 else { return nil }

        // currentRoom is the hero's safe-to-spend for the period (daily/weekly pace, or the
        // month's remaining pool). previousRoom is that SAME pace formula applied to the pool
        // as it would stand had this period repeated last period's spend — so both rooms live
        // on one scale. A one-off lump now lowers the pace by (lump / daysRemaining), never
        // turns a $37 daily pace into a phantom $4,817 "yesterday".
        let current: Double
        let previous: Double

        let poolRemaining = calculator.spendable(for: .month)
        let poolRemainingPrev = poolRemaining + (currentSpend - previousSpend)

        switch period {
        case .month:
            current = poolRemaining
            previous = poolRemainingPrev
        case .week, .day:
            current = calculator.unflooredPace(for: period, remaining: poolRemaining)
            previous = calculator.unflooredPace(for: period, remaining: poolRemainingPrev)
        }

        self.period = period
        self.currentSpend = currentSpend
        self.previousSpend = previousSpend
        self.currentRoom = current
        self.previousRoom = previous
        self.roomDelta = current - previous

        let rawSpendDelta = previousSpend - currentSpend
        self.roomScale = abs(rawSpendDelta) > 0.0001 ? (current - previous) / rawSpendDelta : 1.0
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

    enum BarSide: Equatable {
        case left
        case right
    }

    var id: String { bucket.id }
    let bucket: SpendingBucket
    let currentAmount: Double
    let previousAmount: Double
    let transactionCount: Int
    let roomDelta: Double
    let spendDelta: Double

    var kind: Kind {
        roomDelta >= 0 ? .grew : .shrank
    }

    var barSide: BarSide {
        spendDelta <= 0 ? .left : .right
    }

    /// - Parameter scale: converts each category's raw spend delta into its room (pace)
    ///   impact, matching `HeroCushionSnapshot.roomScale`. Defaults to 1.0 (month / pure
    ///   spend-delta view). The original spend amounts stay raw for display; `roomDelta`
    ///   is the scaled impact used to rank what moved available money.
    static func drivers(from items: [CategoryBreakdownItem], scale: Double = 1.0, limit: Int = 5) -> [HeroCushionDriver] {
        items.compactMap { item in
            let previousAmount = item.previousAmount ?? 0.0
            let currentAmount = item.totalAmount
            let spendDelta = (currentAmount - previousAmount).rounded()
            let delta = ((previousAmount - currentAmount) * scale).rounded()
            guard abs(spendDelta) >= 1 || abs(delta) >= 1 else { return nil }
            return HeroCushionDriver(
                bucket: item.bucket,
                currentAmount: currentAmount,
                previousAmount: previousAmount,
                transactionCount: item.transactionCount,
                roomDelta: delta,
                spendDelta: spendDelta
            )
        }
        .sorted { abs($0.roomDelta) > abs($1.roomDelta) }
        .prefix(limit)
        .map { $0 }
    }
}
