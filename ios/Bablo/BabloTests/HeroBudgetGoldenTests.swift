import Testing
@testable import Bablo

/// Golden-master tests for HeroBudgetCalculator.
///
/// PASS 1 (capture): Tests run and print actual values to the console.
///                   Copy those values in as the expected constants below.
/// PASS 2 (assert):  Uncomment the #expect lines. Tests now act as a tripwire
///                   for the T3 rewrite — if a number changes, it must be intentional.
///
/// Scenarios:
///   S1 — healthy month, day 15 (happy path)
///   S2 — lump charge today (the "day worse than week" case + floor clamp + cap step)
///   S3 — overspent week, not month
///   S4 — cash-capped (safeToSpend, low liquidCash)
///   S5 — no linked accounts (safeToSpend, liquidCash nil → falls back to monthlyPlan math)
///   S6 — week spans month end (dom 30, dim 31, 3 days elapsed in week)
///   S7 — late-month, no paycheck landed (dom 20, income decay active)
@Suite("HeroBudgetGolden")
struct HeroBudgetGoldenTests {

    // MARK: - Shared calc() helper (mirrors HeroBudgetCalculatorTests exactly)

    private func calc(
        income: Double = 5000,
        mandatory: Double = 2000,
        knownIncome: Double = 0,
        extraIncome: Double = 0,
        variableSpend: Double = 500,
        currentWeekVariableSpend: Double = 0,
        todayVariableSpend: Double = 0,
        liquidCashAvailable: Double? = nil,
        spendingPlanMode: SpendingPlanMode = .monthlyPlan,
        upcomingUnpaid: Double = 0,
        prevDay: Double = 0,
        prevWeek: Double = 300,
        prevMonth: Double = 1200,
        dayOfMonth: Int = 15,
        daysInMonth: Int = 31,
        daysElapsedInWeek: Int = 1
    ) -> HeroBudgetCalculator {
        HeroBudgetCalculator(
            monthlyIncome: income,
            monthlyMandatoryExpenses: mandatory,
            knownIncomeThisMonth: knownIncome,
            extraIncomeThisMonth: extraIncome,
            variableSpend: variableSpend,
            currentWeekVariableSpend: currentWeekVariableSpend,
            todayVariableSpend: todayVariableSpend,
            liquidCashAvailable: liquidCashAvailable,
            spendingPlanMode: spendingPlanMode,
            upcomingUnpaidExpenses: upcomingUnpaid,
            previousDayVariableSpend: prevDay,
            previousWeekVariableSpend: prevWeek,
            previousMonthVariableSpend: prevMonth,
            dayOfMonth: dayOfMonth,
            daysInMonth: daysInMonth,
            daysElapsedInWeek: daysElapsedInWeek
        )
    }

    // MARK: - Capture helpers

    /// Print all golden values for a calculator + period. Use in Pass 1.
    private func printGolden(_ c: HeroBudgetCalculator, label: String) {
        for period in [HeroPeriod.day, .week, .month] {
            let p = period == .day ? "day" : period == .week ? "week" : "month"
            let bd = HeroBudgetBreakdownCalculator(calculator: c, period: period)
            print("""
            [\(label)] .\(p)
              spendable:       \(c.spendable(for: period))
              effectiveBudget: \(c.effectiveBudget(for: period))
              fillTarget:      \(c.fillTarget(for: period))
              spentSoFar:      \(c.spentSoFar(for: period))
              steps.count:     \(bd.steps.count)
              steps.titles:    \(bd.steps.map { $0.title })
              steps.amounts:   \(bd.steps.map { $0.amount })
              steps.sum:       \(bd.steps.map { $0.amount }.reduce(0, +))
              finalAmount:     \(bd.finalAmount)
            """)
        }
    }

    // MARK: - S1: Healthy month, day 15 (monthlyPlan)

    /// income 10000, mandatory 2000, variableSpend 1000, weekSpend 300, today 50,
    /// liquidCash 8000 (unused — monthlyPlan mode), dom 15, dim 31.
    @Test func s1_healthy() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 1_000,
            currentWeekVariableSpend: 300,
            todayVariableSpend: 50,
            liquidCashAvailable: 8_000,
            spendingPlanMode: .monthlyPlan,
            dayOfMonth: 15,
            daysInMonth: 31
        )
        printGolden(c, label: "S1")

        // --- Pass 2: replace the values below with the printed output ---
        let weeklyBudget = 8_000.0 / 31.0 * 7.0
        let dailyBudget  = weeklyBudget / 7.0   // = 8000/31

        // Month
        #expect(abs(c.spendable(for: .month) - 7000.0) < 0.01)
        #expect(abs(c.effectiveBudget(for: .month) - 8000.0) < 0.01)
        #expect(c.spentSoFar(for: .month) == 1000.0)
        #expect(abs(c.fillTarget(for: .month) - 0.875) < 0.001)

        // Week
        #expect(abs(c.spendable(for: .week) - 2882.35) < 0.05)
        #expect(abs(c.effectiveBudget(for: .week) - 1806.45) < 0.05)
        #expect(c.spentSoFar(for: .week) == 300.0)

        // Day
        #expect(abs(c.spendable(for: .day) - 411.76) < 0.05)
        #expect(abs(c.effectiveBudget(for: .day) - 258.06) < 0.05)
        #expect(c.spentSoFar(for: .day) == 50.0)

        // Breakdown Month
        let bdMonth = HeroBudgetBreakdownCalculator(calculator: c, period: .month)
        #expect(bdMonth.steps.count == 4)
        #expect(bdMonth.steps[0].title == "Income this month")
        #expect(bdMonth.steps[1].title == "Monthly obligations")
        #expect(bdMonth.steps[2].title == "Goals set aside")
        #expect(bdMonth.steps[3].title == "What you've spent this month")
        #expect(abs(bdMonth.steps.map { $0.amount }.reduce(0, +) - bdMonth.finalAmount) < 0.01)
    }

    // MARK: - S2: Lump charge today (day worse than week, clamp + cap step active)

    /// Income 10000, mandatory 2000. variableSpend 3000, weekSpend 2500, today 2400.
    /// In safeToSpend mode with enough cash so the cash cap does NOT bind
    /// (so we isolate the day→week→month floor clamp, not a cash effect).
    /// Using monthlyPlan so we see the raw clamp without cash interference.
    @Test func s2_lumpToday() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 3_000,
            currentWeekVariableSpend: 2_500,
            todayVariableSpend: 2_400,
            spendingPlanMode: .monthlyPlan,
            dayOfMonth: 15,
            daysInMonth: 31
        )
        printGolden(c, label: "S2")

        #expect(abs(c.spendable(for: .month) - 5000.0) < 0.01)
        #expect(abs(c.effectiveBudget(for: .month) - 8000.0) < 0.01)

        #expect(abs(c.spendable(for: .week) - 2058.82) < 0.05)
        #expect(abs(c.effectiveBudget(for: .week) - 1806.45) < 0.05)

        #expect(abs(c.spendable(for: .day) - 294.11) < 0.05)
        #expect(abs(c.effectiveBudget(for: .day) - 258.06) < 0.05)

        // Day/week breakdown derives the pace from the monthly pool (Level-style) instead
        // of the old prorated-slice-minus-spend chain, so it reconciles to the pace with
        // no scary negative intermediate and no "+$X pace plug".
        let bdWeek = HeroBudgetBreakdownCalculator(calculator: c, period: .week)
        #expect(bdWeek.steps.count == 2)
        #expect(bdWeek.steps[0].title == "Safe to spend this month")
        #expect(bdWeek.steps[1].title == "Held for the rest of the month")
        #expect(abs(bdWeek.steps.map { $0.amount }.reduce(0, +) - bdWeek.finalAmount) < 0.01)

        let bdDay = HeroBudgetBreakdownCalculator(calculator: c, period: .day)
        #expect(bdDay.steps.count == 2)
        #expect(bdDay.steps[0].title == "Safe to spend this month")
        #expect(bdDay.steps[1].title == "Held for the rest of the month")
        #expect(abs(bdDay.steps.map { $0.amount }.reduce(0, +) - bdDay.finalAmount) < 0.01)
    }

    /// S2b: Same scenario in safeToSpend mode WITH enough cash (so cash cap doesn't bind,
    /// but the day→week floor clamp DOES fire). This exercises the cap step.
    @Test func s2b_lumpToday_safeToSpend_clampFires() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 3_000,
            currentWeekVariableSpend: 2_500,
            todayVariableSpend: 2_400,
            liquidCashAvailable: 20_000,
            spendingPlanMode: .safeToSpend,
            dayOfMonth: 15,
            daysInMonth: 31
        )
        printGolden(c, label: "S2b")

        #expect(abs(c.spendable(for: .month) - 20000.0) < 0.01)
        #expect(abs(c.effectiveBudget(for: .month) - 20000.0) < 0.01)

        #expect(abs(c.spendable(for: .week) - 8235.29) < 0.05)
        #expect(abs(c.effectiveBudget(for: .week) - 4516.12) < 0.05)

        #expect(abs(c.spendable(for: .day) - 1176.47) < 0.05)
        #expect(abs(c.effectiveBudget(for: .day) - 645.16) < 0.05)

        let bdMonth = HeroBudgetBreakdownCalculator(calculator: c, period: .month)
        #expect(bdMonth.steps.count == 3)
        #expect(bdMonth.steps[0].title == "Net cash on hand")
        #expect(bdMonth.steps[1].title == "Upcoming bills")
        #expect(bdMonth.steps[2].title == "Goals set aside")

        let bdDay = HeroBudgetBreakdownCalculator(calculator: c, period: .day)
        #expect(bdDay.steps.count == 2)
        #expect(bdDay.steps[0].title == "Safe to spend this month")
        #expect(bdDay.steps[1].title == "Held for the rest of the month")
        #expect(abs(bdDay.steps.map { $0.amount }.reduce(0, +) - bdDay.finalAmount) < 0.01)
    }

    // MARK: - S3: Overspent week, not month (monthlyPlan)

    /// income 6000, mandatory 1000. variableSpend 1500, weekSpend 1400, today 100.
    @Test func s3_overspentWeekNotMonth() {
        let c = calc(
            income: 6_000,
            mandatory: 1_000,
            variableSpend: 1_500,
            currentWeekVariableSpend: 1_400,
            todayVariableSpend: 100,
            spendingPlanMode: .monthlyPlan,
            dayOfMonth: 15,
            daysInMonth: 31
        )
        printGolden(c, label: "S3")

        #expect(abs(c.spendable(for: .month) - 3500.0) < 0.01)
        #expect(abs(c.spendable(for: .week) - 1441.17) < 0.05)
        #expect(c.spendable(for: .week) > 0, "week pace is positive because remaining pool is high")
        #expect(c.spendable(for: .month) > 0, "month must be healthy")
        #expect(c.fillTarget(for: .week) == 1.0)

        let bdMonth = HeroBudgetBreakdownCalculator(calculator: c, period: .month)
        #expect(bdMonth.steps.count == 4)
        #expect(abs(bdMonth.steps.map { $0.amount }.reduce(0, +) - bdMonth.finalAmount) < 0.01)
    }

    // MARK: - S4: Cash-capped (safeToSpend, low liquidCash)

    /// income 10000, mandatory 2000, liquidCash 1000, upcoming 300. No variable spend.
    @Test func s4_cashCapped() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 0,
            liquidCashAvailable: 1_000,
            spendingPlanMode: .safeToSpend,
            upcomingUnpaid: 300,
            dayOfMonth: 15,
            daysInMonth: 31
        )
        printGolden(c, label: "S4")

        #expect(abs(c.spendable(for: .month) - 700.0) < 0.01)
        #expect(abs(c.effectiveBudget(for: .month) - 700.0) < 0.01)

        let bd = HeroBudgetBreakdownCalculator(calculator: c, period: .month)
        #expect(bd.steps.count == 3)
        #expect(bd.steps[0].title == "Net cash on hand")
        #expect(bd.steps[1].title == "Upcoming bills")
        #expect(bd.steps[2].title == "Goals set aside")
        #expect(abs(bd.steps.map { $0.amount }.reduce(0, +) - bd.finalAmount) < 0.01)
    }

    // MARK: - S5: No linked accounts (safeToSpend with nil cash → falls back to monthlyPlan)

    /// income 5000, mandatory 1000, liquidCash nil.
    @Test func s5_noAccounts() {
        let c = calc(
            income: 5_000,
            mandatory: 1_000,
            variableSpend: 0,
            liquidCashAvailable: nil,
            spendingPlanMode: .safeToSpend,
            dayOfMonth: 15,
            daysInMonth: 31
        )
        printGolden(c, label: "S5")

        #expect(c.spendable(for: .month) == 0.0)

        let bd = HeroBudgetBreakdownCalculator(calculator: c, period: .month)
        #expect(bd.steps.count == 3)
        #expect(bd.steps[0].title == "Net cash on hand")
        #expect(bd.steps[1].title == "Upcoming bills")
        #expect(bd.steps[2].title == "Goals set aside")
        #expect(abs(bd.steps.map { $0.amount }.reduce(0, +) - bd.finalAmount) < 0.01)
    }

    // MARK: - S6: Week spans month end (dom 30, dim 31, 3 days elapsed)

    /// income 10000, mandatory 2000. dom=30, dim=31, daysElapsedInWeek=3, no spend.
    @Test func s6_weekSpansMonthEnd() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 0,
            currentWeekVariableSpend: 0,
            spendingPlanMode: .monthlyPlan,
            dayOfMonth: 30,
            daysInMonth: 31,
            daysElapsedInWeek: 3
        )
        printGolden(c, label: "S6")

        #expect(abs(c.spendable(for: .month) - 8000.0) < 0.01)
        #expect(abs(c.spendable(for: .week) - 8000.0) < 0.01)
        #expect(abs(c.spendable(for: .day) - 4000.0) < 0.01)

        let bdWeek = HeroBudgetBreakdownCalculator(calculator: c, period: .week)
        #expect(abs(bdWeek.steps.map { $0.amount }.reduce(0, +) - bdWeek.finalAmount) < 0.01)
    }

    // MARK: - S7: Late-month, no paycheck (income decay active, dom 20, dim 31)

    /// income 9000, mandatory 0, knownIncome 0, liquidCash provided (triggers decay).
    @Test func s7_lateMonthNoPaycheck() {
        let c = calc(
            income: 9_000,
            mandatory: 0,
            knownIncome: 0,
            variableSpend: 0,
            liquidCashAvailable: 5_000,  // non-nil triggers decay
            spendingPlanMode: .monthlyPlan,
            dayOfMonth: 20,
            daysInMonth: 31
        )
        printGolden(c, label: "S7")

        let decayFactor = max(0.0, 1.0 - (20.0 - 15.0) / (31.0 - 15.0))
        let expectedIncome = 9_000.0 * decayFactor
        #expect(abs(c.effectiveIncome - expectedIncome) < 0.001)
        #expect(abs(c.monthlyDiscretionary - expectedIncome) < 0.001)

        #expect(abs(c.spendable(for: .month) - expectedIncome) < 0.001)
        #expect(c.fillTarget(for: .month) == 1.0)

        let bd = HeroBudgetBreakdownCalculator(calculator: c, period: .month)
        #expect(bd.steps.count == 3)
        #expect(bd.steps[0].title == "Income this month")
        #expect(bd.steps[1].title == "Goals set aside")
        #expect(bd.steps[2].title == "What you've spent this month")
        #expect(abs(bd.steps.map { $0.amount }.reduce(0, +) - bd.finalAmount) < 0.01)
    }
}
