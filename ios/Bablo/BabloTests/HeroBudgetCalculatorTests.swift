import Testing
@testable import Bablo

@Suite("HeroBudgetCalculator")
struct HeroBudgetCalculatorTests {

    // MARK: - Helpers

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

    @Test func breakdownReconcilesMonthToHeroSpendable() {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 725,
            currentWeekVariableSpend: 180,
            todayVariableSpend: 45
        )

        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .month)

        #expect(breakdown.finalAmount == c.spendable(for: .month))
        #expect(breakdown.reconciledAmount == c.spendable(for: .month))
        #expect(breakdown.steps.map(\.amount).reduce(0, +) == c.spendable(for: .month))
    }

    @Test func cushionSnapshotComparesSpendableRoomAgainstPreviousPeriod() {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 700,
            currentWeekVariableSpend: 188,
            prevWeek: 230,
            daysInMonth: 30
        )

        let snapshot = HeroCushionSnapshot(calculator: c, period: .week)

        #expect(snapshot?.currentRoom == c.spendable(for: .week))
        #expect(snapshot?.roomDelta == 42)
        #expect(snapshot?.previousRoom == c.spendable(for: .week) - 42)
        #expect(snapshot?.hasMoreRoom == true)
    }

    @Test func cushionSnapshotNilWhenIncomeBudgetIsUnavailable() {
        let c = calc(
            income: 0,
            mandatory: 0,
            variableSpend: 200,
            prevMonth: 300
        )

        let snapshot = HeroCushionSnapshot(calculator: c, period: .month)

        #expect(snapshot == nil)
    }

    @Test func cushionSnapshotSupportsDayComparison() {
        let c = calc(todayVariableSpend: 0, prevDay: 32)

        let snapshot = HeroCushionSnapshot(calculator: c, period: .day)

        #expect(snapshot != nil)
        #expect(snapshot?.roomDelta == 32)
        #expect(snapshot?.hasMoreRoom == true)
    }

    @Test func cushionVerdictHeadlineShowsStillOverWhenCurrentRoomIsNegativeButImproved() throws {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 3_000,
            currentWeekVariableSpend: 2_628,
            prevWeek: 22_676,
            daysInMonth: 31
        )
        let snapshot = try #require(HeroCushionSnapshot(calculator: c, period: .week))

        #expect(snapshot.currentRoom < 0)
        #expect(snapshot.roomDelta > 0)
        #expect(CushionVerdictCopy.headline(for: snapshot, comparisonName: "last week") == "Still over, but better than last week.")
    }

    @Test func cushionDriversInvertSpendDeltaIntoRoomDelta() {
        let items = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 49, transactionCount: 3, percentOfTotal: 0.4, previousAmount: 80),
            CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 48, transactionCount: 2, percentOfTotal: 0.3, previousAmount: 30),
            CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 28, transactionCount: 2, percentOfTotal: 0.2, previousAmount: 40),
        ]

        let drivers = HeroCushionDriver.drivers(from: items)

        #expect(drivers.map(\.roomDelta) == [31, -18, 12])
        #expect(drivers[0].kind == .grew)
        #expect(drivers[1].kind == .shrank)
    }

    @Test func breakdownReconcilesWeekToHeroSpendable() {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 900,
            currentWeekVariableSpend: 210,
            daysInMonth: 30
        )

        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .week)

        #expect(abs(breakdown.finalAmount - c.spendable(for: .week)) < 0.001)
        #expect(abs(breakdown.reconciledAmount - c.spendable(for: .week)) < 0.001)
    }

    @Test func breakdownUsesSafeToSpendCashCapLanguageWhenCashBinds() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 500,
            liquidCashAvailable: 1_000,
            spendingPlanMode: .safeToSpend,
            upcomingUnpaid: 300
        )

        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .month)

        // Cash-capped mode: no context rows (step titles are self-explanatory), 2-step flow
        #expect(breakdown.contextRows.isEmpty)
        #expect(breakdown.isCashCapped)
        #expect(breakdown.steps.first?.title == "Start with safe cash")
        #expect(breakdown.steps.count == 2)
    }

    @Test func breakdownMonthlyIncomeModeHasThreeSteps() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 500
        )

        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .month)

        #expect(!breakdown.isCashCapped)
        #expect(breakdown.steps.count == 3)
        #expect(breakdown.steps[0].title == "Income this month")
        #expect(breakdown.steps[1].title == "Monthly obligations")
        #expect(breakdown.steps[2].title == "What you've spent this month")
        #expect(breakdown.steps.map(\.amount).reduce(0, +) == c.spendable(for: .month))
    }

    @Test func breakdownMonthlyIncomeModeNoMandatoryHasTwoSteps() {
        let c = calc(income: 5_000, mandatory: 0, variableSpend: 300)
        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .month)

        #expect(breakdown.steps.count == 2)
        #expect(breakdown.steps[0].title == "Income this month")
        #expect(breakdown.steps[1].title == "What you've spent this month")
        #expect(breakdown.steps.map(\.amount).reduce(0, +) == c.spendable(for: .month))
    }

    @Test func accountAuditOmitsNonLiquidAccountsFromNotCountedExplainer() {
        let rows = HeroBudgetBreakdownCalculator.accountAuditRows(
            accounts: [
                .init(name: "Chase Checking", mask: "3382", type: "depository", currentBalance: 1_247),
                .init(name: "Apple Card", mask: nil, type: "credit", currentBalance: 118),
                .init(name: "Robinhood", mask: nil, type: "investment", currentBalance: 2_340),
                .init(name: "Student Loan", mask: nil, type: "loan", currentBalance: 900)
            ]
        )

        #expect(rows.counted.map(\.displayAmount) == ["$1,247", "-$118"])
        #expect(rows.notCounted.isEmpty)
        #expect(rows.countedTotal == 1_129)
    }

    // MARK: - Monthly discretionary

    @Test func monthlyDiscretionaryPositive() {
        let c = calc(income: 5000, mandatory: 2000)
        #expect(c.monthlyDiscretionary == 3000)
    }

    @Test func monthlyDiscretionaryUsesActualIncomeWhenProfileBudgetIsEmpty() {
        let c = calc(income: 0, mandatory: 0, knownIncome: 2500, extraIncome: 400)
        #expect(c.monthlyDiscretionary == 2900)
    }

    @Test func monthlyDiscretionaryUsesHigherProfileIncomeAndAddsExtraIncome() {
        let c = calc(income: 5000, mandatory: 1500, knownIncome: 3000, extraIncome: 250)
        #expect(c.monthlyDiscretionary == 3750)
    }

    @Test func monthlyDiscretionaryDeficitFloorsToZero() {
        let c = calc(income: 1000, mandatory: 2000)
        #expect(c.monthlyDiscretionary == 0)
    }

    @Test func monthlyDiscretionaryExactlyZero() {
        let c = calc(income: 2000, mandatory: 2000)
        #expect(c.monthlyDiscretionary == 0)
    }

    // MARK: - Weekly discretionary (prorated from monthly)

    @Test func weeklyDiscretionaryProration() {
        // $3000/31 * 7 ≈ $677.41
        let c = calc(income: 5000, mandatory: 2000, daysInMonth: 31)
        let expected = 3000.0 / 31.0 * 7.0
        #expect(abs(c.weeklyDiscretionary - expected) < 0.001)
    }

    @Test func weeklyDiscretionaryZeroDaysInMonthGuard() {
        let c = calc(income: 5000, mandatory: 2000, daysInMonth: 0)
        #expect(c.weeklyDiscretionary == 0)
    }

    // MARK: - Spent so far: month

    @Test func monthlySpentSoFarIsVariableSpend() {
        let c = calc(variableSpend: 750)
        #expect(c.spentSoFar(for: .month) == 750)
    }

    // MARK: - Spent so far: week — actual current-week spend, no MTD proration

    @Test func weeklySpentSoFarUsesActualCurrentWeekSpend() {
        // MTD spend is 1000 over 20 days, but actual this-week spend is 200.
        // Result must be 200, NOT (1000/20)*7 = 350.
        let c = calc(variableSpend: 1000, currentWeekVariableSpend: 200)
        #expect(c.spentSoFar(for: .week) == 200)
    }

    @Test func weeklySpentSoFarIsIndependentOfMTDPattern() {
        // Same week spend, wildly different MTD amounts → same weekly result.
        let early = calc(variableSpend: 50,   currentWeekVariableSpend: 80)
        let late  = calc(variableSpend: 1200, currentWeekVariableSpend: 80)
        #expect(early.spentSoFar(for: .week) == late.spentSoFar(for: .week))
    }

    @Test func weeklySpentSoFarZeroWhenNothingSpentThisWeek() {
        let c = calc(variableSpend: 900, currentWeekVariableSpend: 0)
        #expect(c.spentSoFar(for: .week) == 0)
    }

    // MARK: - Spent so far: day — actual today's spend, not a monthly average

    @Test func dailySpentSoFarUsesActualTodaySpend() {
        // MTD is $500 over 15 days (average $33/day), but today's actual spend is $120.
        // Result must be 120, NOT 500/15 = 33.33.
        let c = calc(variableSpend: 500, todayVariableSpend: 120)
        #expect(c.spentSoFar(for: .day) == 120)
    }

    @Test func dailySpentSoFarZeroWhenNothingSpentToday() {
        let c = calc(variableSpend: 900, todayVariableSpend: 0)
        #expect(c.spentSoFar(for: .day) == 0)
    }

    // MARK: - Spendable (monthlyPlan mode)

    @Test func spendableMonthNothingSpent() {
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 0)
        #expect(c.spendable(for: .month) == 3000)
    }

    @Test func spendableMonthOverBudgetCanGoNegative() {
        let c = calc(income: 3000, mandatory: 2000, variableSpend: 2000)
        #expect(c.spendable(for: .month) == -1000)
    }

    @Test func spendableWeekPositive() {
        // weekly discretionary = 3000/31*7 ≈ 677.42
        // actual week spend = 233
        // spendable ≈ 444.42
        let weekSpent = 233.0
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 500,
                     currentWeekVariableSpend: weekSpent, daysInMonth: 31)
        let disc = 3000.0 / 31.0 * 7.0
        let expected = disc - weekSpent
        #expect(abs(c.spendable(for: .week) - expected) < 0.001)
    }

    // MARK: - safeToSpend mode

    @Test func monthlyPlanModeDoesNotCapByLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 1_000,
            liquidCashAvailable: 3_500,
            spendingPlanMode: .monthlyPlan
        )
        #expect(c.totalDiscretionary(for: .month) == 8_000)
        #expect(c.spendable(for: .month) == 7_000)
    }

    @Test func safeToSpendCapsMonthByLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 1_000,
            liquidCashAvailable: 3_500,
            spendingPlanMode: .safeToSpend
        )
        #expect(c.totalDiscretionary(for: .month) == 8_000)
        #expect(c.spendable(for: .month) == 3_500)
    }

    /// The liquid-cash cap must NOT be applied to the weekly period.
    /// Liquid cash is a total balance, not a weekly allowance — capping the
    /// week to the same figure as the month produces an identical number on
    /// both tabs and misleads the user about how much they can spend week-by-week.
    /// In safeToSpend mode, the weekly spendable remaining must be capped by
    /// the remaining cash available for the month.
    @Test func safeToSpendCapsWeekByLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            variableSpend: 0,
            currentWeekVariableSpend: 0,
            liquidCashAvailable: 500,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        // monthly discretionary = 9000
        // monthly spendable = min(9000, 500 + 0) - 0 = 500
        // weekly plan remaining = 9000/30*7 = 2100
        // weekly capped spendable = min(2100, 500) = 500
        #expect(abs(c.spendable(for: .week) - 500) < 0.01)
    }

    /// In safeToSpend mode, the daily spendable remaining must be capped by
    /// the remaining cash available for the month.
    @Test func safeToSpendCapsDayByLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            todayVariableSpend: 0,
            liquidCashAvailable: 100,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        // dailyPlan = 300, liquidCashAvailable = 100
        // daily capped spendable = min(300, 100) = 100
        #expect(abs(c.spendable(for: .day) - 100) < 0.01)
    }

    @Test func safeToSpendFallsBackToMonthlyPlanWhenCashIsUnavailable() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 1_000,
            liquidCashAvailable: nil,
            spendingPlanMode: .safeToSpend
        )
        #expect(c.spendable(for: .month) == 7_000)
    }

    /// When liquid cash < plan remaining and nothing has been spent yet,
    /// the fill should be 100 % (full tank), not 6% (liquid/plan ratio).
    @Test func safeToSpendFillIsFullAtStartOfMonthWhenNothingSpent() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 0,
            liquidCashAvailable: 500,
            spendingPlanMode: .safeToSpend
        )
        // spendable = min(8000, 500) = 500
        // effectiveBudget = spentSoFar(0) + spendable(500) = 500
        // fillTarget = 500 / 500 = 1.0
        #expect(abs(c.fillTarget(for: .month) - 1.0) < 0.001)
    }

    /// Fill should decrease proportionally as variable spend is recorded.
    @Test func safeToSpendFillDecreasesWithSpend() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 500,
            liquidCashAvailable: 3_500,
            spendingPlanMode: .safeToSpend
        )
        // planRemaining = 8000 - 500 = 7500
        // spendable = min(7500, 3500) = 3500
        // effectiveBudget = spentSoFar(500) + spendable(3500) = 4000
        // fillTarget = 3500 / 4000 = 0.875
        #expect(abs(c.fillTarget(for: .month) - 0.875) < 0.001)
    }

    /// Negative liquid balance (more debt than cash) must not show as available.
    @Test func negativeLiquidCashFloorsSpendableToZero() {
        let c = calc(
            income: 5_000,
            mandatory: 1_000,
            variableSpend: 0,
            liquidCashAvailable: -200,   // net negative: credit > depository
            spendingPlanMode: .safeToSpend
        )
        #expect(c.spendable(for: .month) == 0)
    }

    // MARK: - Fill target

    @Test func fillTargetNormalCase() {
        // 50% spent → fillTarget = 0.5
        let c = calc(income: 4000, mandatory: 2000, variableSpend: 1000, daysInMonth: 30)
        #expect(abs(c.fillTarget(for: .month) - 0.5) < 0.001)
    }

    @Test func fillTargetClampsToMinimum() {
        // fully spent → would be 0, clamped to the deliberate red-pool minimum
        let c = calc(income: 3000, mandatory: 2000, variableSpend: 1500)
        #expect(c.fillTarget(for: .month) == 0.10)
    }

    @Test func fillTargetClampsToMaximum() {
        // nothing spent → 1.0
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 0)
        #expect(c.fillTarget(for: .month) == 1.0)
    }

    @Test func fillTargetZeroIncomeFallsToMinimum() {
        let c = calc(income: 0, mandatory: 0, variableSpend: 0)
        #expect(c.fillTarget(for: .month) == 0.10)
        #expect(c.fillTarget(for: .week) == 0.10)
    }

    // MARK: - Delta label

    @Test func deltaLabelWeekPositiveWhenSpentLess() {
        // prev week $300, this week $150 → saved $150 → "+$150 vs last wk"
        let c = calc(variableSpend: 500, currentWeekVariableSpend: 150, prevWeek: 300)
        let label = c.deltaLabel(for: .week)
        #expect(label != nil)
        #expect(label!.hasPrefix("+"))
        #expect(label!.hasSuffix("vs last wk"))
    }

    @Test func deltaLabelWeekNegativeWhenSpentMore() {
        // prev week $100, this week $300 → overspent $200 → "-$200 vs last wk"
        let c = calc(variableSpend: 500, currentWeekVariableSpend: 300, prevWeek: 100)
        let label = c.deltaLabel(for: .week)
        #expect(label != nil)
        #expect(label!.hasPrefix("-"))
        #expect(label!.hasSuffix("vs last wk"))
    }

    /// The week delta must compare actual week-vs-week figures, not an MTD proration.
    @Test func deltaLabelWeekUsesActualCurrentWeekSpend() {
        // If week delta used proration: (500/20)*7 = 175 → prev 300 → +$125
        // With actual current-week spend = 250: prev 300 → +$50
        let c = calc(variableSpend: 500, currentWeekVariableSpend: 250, prevWeek: 300)
        let label = c.deltaLabel(for: .week)
        #expect(label == "+$50 vs last wk")
    }

    @Test func deltaLabelMonthPositive() {
        // prev month $1200, curr month $500 → saved $700 → "+$700 vs last mo"
        let c = calc(variableSpend: 500, prevMonth: 1200)
        let label = c.deltaLabel(for: .month)
        #expect(label == "+$700 vs last mo")
    }

    @Test func deltaLabelMonthNegative() {
        // prev month $400, curr month $500 → overspent $100 → "-$100 vs last mo"
        let c = calc(variableSpend: 500, prevMonth: 400)
        let label = c.deltaLabel(for: .month)
        #expect(label == "-$100 vs last mo")
    }

    @Test func deltaLabelNilWhenBothZero() {
        let c = calc(variableSpend: 0, currentWeekVariableSpend: 0, prevWeek: 0, prevMonth: 0)
        #expect(c.deltaLabel(for: .week) == nil)
        #expect(c.deltaLabel(for: .month) == nil)
    }

    @Test func deltaLabelNotNilWhenOnlyCurrentIsNonZero() {
        // prev = 0, curr > 0 → negative delta label is still shown
        let c = calc(variableSpend: 200, prevMonth: 0)
        let label = c.deltaLabel(for: .month)
        #expect(label != nil)
        #expect(label!.hasPrefix("-"))
    }

    @Test func deltaLabelShownWhenOnlyPreviousPeriodHasSpend() {
        let c = calc(variableSpend: 0, prevMonth: 25_878)
        #expect(c.deltaLabel(for: .month) == "+$26K vs last mo")
    }

    /// Delta label must appear when actual income is received (knownIncome > 0),
    /// even if the user has not yet set up a profile with monthlyIncome.
    @Test func deltaLabelShownWhenOnlyKnownIncomeExists() {
        // Regression: previously the guard was `monthlyIncome > 0`, which hid the
        // delta for new users who have real paychecks but no profile budget set.
        // income=0, knownIncome=6000, mandatory=2000 → monthlyDiscretionary=4000
        // prevMonth=3000 is within budget → delta label is shown
        let c = calc(income: 0, knownIncome: 6000, variableSpend: 1000, prevMonth: 3000)
        let label = c.deltaLabel(for: .month)
        #expect(label != nil, "delta must be visible when effectiveIncome > 0")
        #expect(label!.hasPrefix("+"))   // prev(3000) > curr(1000) → +$2,000 vs last mo
    }

    @Test func deltaLabelNilWhenIncomeBudgetIsUnavailable() {
        let c = calc(
            income: 0,
            mandatory: 0,
            variableSpend: 200,
            prevMonth: 300
        )
        let label = c.deltaLabel(for: .month)
        #expect(label == nil)
    }

    @Test func deltaLabelDayPositiveWhenSpentLessThanYesterday() {
        let c = calc(todayVariableSpend: 0, prevDay: 42)
        #expect(c.deltaLabel(for: .day) == "+$42 vs yesterday")
    }

    @Test func deltaLabelDayNegativeWhenSpentMoreThanYesterday() {
        let c = calc(todayVariableSpend: 64, prevDay: 12)
        #expect(c.deltaLabel(for: .day) == "-$52 vs yesterday")
    }

    @Test func deltaLabelWeekShownWhenCurrentWeekIsZeroButPreviousWeekHasSpend() {
        let c = calc(variableSpend: 0, currentWeekVariableSpend: 0, prevWeek: 88)
        #expect(c.deltaLabel(for: .week) == "+$88 vs last wk")
    }

    /// The pill compares spend period over period, so it should still appear when
    /// last period exceeded the current budget model.
    @Test func deltaLabelMonthShownWhenPreviousMonthExceededBudget() {
        // income=10990, mandatory=4366 → discretionary=6624
        // prevMonthSpend=30900 > 6624, but spend comparison is still meaningful.
        let c = calc(income: 10_990, mandatory: 4_366, variableSpend: 5_990, prevMonth: 30_900)
        #expect(c.deltaLabel(for: .month) == "+$25K vs last mo")
    }

    /// Previous month within budget — delta is a valid remaining-budget comparison and must show.
    @Test func deltaLabelMonthShownWhenPreviousMonthWithinBudget() {
        // income=10990, mandatory=4366 → discretionary=6624
        // prevMonthSpend=4000 <= 6624, currSpend=5990 → delta = 4000-5990 = -1990 → "-$1,990 vs last mo"
        let c = calc(income: 10_990, mandatory: 4_366, variableSpend: 5_990, prevMonth: 4_000)
        #expect(c.deltaLabel(for: .month) != nil)
    }

    /// Same behavior for weeks: the chip remains a real week-over-week comparison.
    @Test func deltaLabelWeekShownWhenPreviousWeekExceededBudget() {
        // discretionary=3000/31*7≈677, prevWeek=1500 > 677, still shown.
        let c = calc(income: 5_000, mandatory: 2_000, currentWeekVariableSpend: 200, prevWeek: 1_500)
        #expect(c.deltaLabel(for: .week) == "+$1.3K vs last wk")
    }

    @Test func deltaLabelWeekCurrentInRedImprovedUsesInTheRedCopy() {
        // Weekly room is about -$1,951, but last week was much deeper in the red.
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            currentWeekVariableSpend: 2_628,
            prevWeek: 22_676,
            daysInMonth: 31
        )
        #expect(c.spendable(for: .week) < 0)
        #expect(c.deltaLabel(for: .week) == "$20K less in the red vs last wk")
    }

    // MARK: - Monthly cap: week/day cannot exceed what's left for the month

    /// Core regression: when the user is near month-end with little monthly budget left,
    /// the weekly remaining must not exceed the monthly remaining.
    /// Before the fix, week showed $1,485 while month showed $780 — impossible.
    @Test func weekSpendableCannotExceedMonthlyRemaining() {
        // Monthly discretionary = $6,626, spent $5,846 → $780 left for the month.
        // Weekly budget = 6626/31*7 = $1,496, this-week spend = $11 → $1,485 raw.
        // Expected: week spendable = min($1,485, $780) = $780.
        let c = calc(
            income: 6_626,
            mandatory: 0,
            variableSpend: 5_846,
            currentWeekVariableSpend: 11,
            daysInMonth: 31
        )
        let monthRemaining = c.monthlyDiscretionary - c.monthlySpentSoFar
        #expect(c.spendable(for: .week) <= monthRemaining + 0.01,
                "weekly spendable must not exceed monthly remaining")
        #expect(abs(c.spendable(for: .week) - monthRemaining) < 0.01,
                "weekly spendable should equal the monthly remaining when it is the binding constraint")
    }

    @Test func dailyBudgetIsWeeklyBudgetDividedBy7() {
        // Monthly remaining = $50, weekly budget capped at $50.
        // Daily budget = $50 / 7 ≈ $7.14 — NOT the full $50 monthly remaining.
        // Spending $7.14 per day for 7 days = $50 = the weekly cap.
        let c = calc(
            income: 6_626,
            mandatory: 0,
            variableSpend: 6_576,
            todayVariableSpend: 0,
            daysInMonth: 31
        )
        let expectedWeekly = c.budget(for: .week)  // $50 (capped by monthly remaining)
        let expectedDaily  = expectedWeekly / 7
        #expect(abs(c.budget(for: .day) - expectedDaily) < 0.01)
        #expect(abs(c.spendable(for: .day) - expectedDaily) < 0.01)
    }

    @Test func dailyBudgetIsWeeklyDivBy7_NormalCase() {
        // No cap binding: weekly = 3000/31*7 ≈ $677.42; daily = $677.42/7 ≈ $96.77
        let c = calc(income: 5_000, mandatory: 2_000, variableSpend: 0, daysInMonth: 31)
        let expectedDaily = c.budget(for: .week) / 7
        #expect(abs(c.budget(for: .day) - expectedDaily) < 0.001)
    }

    @Test func weekSpendableIsUncappedWhenMonthHasPlenty() {
        // Early in the month — monthly remaining > weekly budget, so no cap.
        // Monthly discretionary = $3,000, spent $200 → $2,800 left.
        // Weekly = 3000/31*7 ≈ $677, this-week spend = $0 → raw $677.
        // $677 < $2,800, so monthly cap does not kick in.
        let c = calc(
            income: 3_000,
            mandatory: 0,
            variableSpend: 200,
            currentWeekVariableSpend: 0,
            daysInMonth: 31
        )
        let weekBudget = 3_000.0 / 31.0 * 7.0
        #expect(abs(c.spendable(for: .week) - weekBudget) < 0.01,
                "when monthly remaining exceeds weekly budget, weekly spendable should equal weekly budget")
    }

    @Test func monthSpendableIsNeverAffectedByCap() {
        // The monthly cap only applies to sub-month periods; month itself is unchanged.
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 4000)
        // monthlyDiscretionary = 3000, variableSpend = 4000 → spendable = -1000
        #expect(c.spendable(for: .month) == -1000)
    }

    @Test func weekAndMonthConvergeAtMonthEnd() {
        // When the remaining month is shorter than a week (e.g., 3 days left),
        // the weekly spendable is capped well below the weekly budget.
        // Monthly = $3,000, spent $2,900 → $100 left. Weekly budget = ~$677.
        // Week spendable = min(677, 100) = $100.
        let c = calc(
            income: 3_000,
            mandatory: 0,
            variableSpend: 2_900,
            currentWeekVariableSpend: 0,
            daysInMonth: 31
        )
        #expect(abs(c.spendable(for: .week) - 100) < 0.01)
        #expect(abs(c.spendable(for: .month) - 100) < 0.01)
    }

    @Test func weeklyCap_NotTriggeredWhenWeeklyIsAlreadyBelowMonthly() {
        // Confirm the cap is transparent when weekly plan remaining < monthly remaining.
        let weeklySpend = 200.0
        let c = calc(
            income: 5_000,
            mandatory: 0,
            variableSpend: 100,          // only $100 spent this month → $4,900 remaining
            currentWeekVariableSpend: weeklySpend,
            daysInMonth: 31
        )
        let weekBudget  = 5_000.0 / 31.0 * 7.0
        let weekPlanRem = max(0, weekBudget - weeklySpend)
        // Monthly remaining ($4,900) far exceeds weekly remaining (~$900), cap inactive.
        #expect(abs(c.spendable(for: .week) - weekPlanRem) < 0.01)
    }

    // MARK: - Effective budget (denominator for "X of Y" display)

    /// When no constraint is binding, effectiveBudget == totalDiscretionary for the period.
    @Test func effectiveBudgetEqualsDiscretionaryWhenNoCap() {
        let c = calc(income: 5_000, mandatory: 0, variableSpend: 100,
                     currentWeekVariableSpend: 50, daysInMonth: 31)
        let weekBudget = 5_000.0 / 31.0 * 7.0
        #expect(abs(c.effectiveBudget(for: .week) - weekBudget) < 0.01)
    }

    /// When the monthly cap is binding, effectiveBudget = weeklySpent + monthlyRemaining.
    /// This ensures "X of Y" in the UI implies the correct amount spent this week,
    /// not an inflated figure caused by the uncapped weekly budget in the denominator.
    @Test func effectiveBudgetShrinksWhenMonthlyCaps() {
        // monthlyDiscretionary = $6,626, spent $5,846 → $780 monthly remaining.
        // This week: spent $203. Weekly budget ≈ $1,496.
        // effectiveBudget = $203 + $780 = $983 (not $1,496).
        let c = calc(
            income: 6_626,
            mandatory: 0,
            variableSpend: 5_846,
            currentWeekVariableSpend: 203,
            daysInMonth: 31
        )
        #expect(abs(c.effectiveBudget(for: .week) - 983) < 1,
                "effectiveBudget must shrink to weeklySpent + monthlyRemaining when cap is binding")
    }

    // MARK: - Paycheck Illusion (Edge Case D)

    @Test func effectiveIncomeDecaysAfterDay15WhenNoPaycheckAndAccountsLinked() {
        // Day 20 of 30, no paycheck (knownIncome = 0), and has linked accounts (liquidCashAvailable != nil)
        // Decay factor on Day 20 of 30-day month = 1.0 - (20 - 15) / (30 - 15) = 1.0 - 5/15 = 0.6667
        // expected income = 5000 * 0.6667 = 3333.33
        let c = calc(income: 5000, knownIncome: 0, liquidCashAvailable: 1000, dayOfMonth: 20, daysInMonth: 30)
        #expect(abs(c.effectiveIncome - 3333.33) < 0.1)
    }

    @Test func effectiveIncomeDoesNotDecayEarlyInMonth() {
        // Day 10, no paycheck, should have no decay
        let c = calc(income: 5000, knownIncome: 0, liquidCashAvailable: 1000, dayOfMonth: 10, daysInMonth: 30)
        #expect(c.effectiveIncome == 5000)
    }

    @Test func effectiveIncomeDoesNotDecayWhenPaycheckHasLanded() {
        // Day 20, paycheck has landed (knownIncome > 0) -> no decay!
        let c = calc(income: 5000, knownIncome: 2500, liquidCashAvailable: 1000, dayOfMonth: 20, daysInMonth: 30)
        #expect(c.effectiveIncome == 5000)
    }

    @Test func effectiveIncomeDoesNotDecayWhenNoAccountsLinked() {
        // Day 20, no paycheck, but no accounts linked (liquidCashAvailable == nil) -> no decay!
        let c = calc(income: 5000, knownIncome: 0, liquidCashAvailable: nil, dayOfMonth: 20, daysInMonth: 30)
        #expect(c.effectiveIncome == 5000)
    }

    // MARK: - Stable Denominators & Negative Spendable (Edge Case A)

    @Test func spendableMonthCanGoNegativeWhenOverspent() {
        // monthly discretionary = 3000, spent = 3500 -> spendable = -500
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 3500)
        #expect(c.spendable(for: .month) == -500)
    }

    @Test func effectiveBudgetDoesNotExpandWhenOverspent() {
        // discretionary = 3000, spent = 3500. denominator remains 3000.
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 3500)
        #expect(c.effectiveBudget(for: .month) == 3000)
    }

    @Test func weekSpendableCanGoNegativeWhenOverspent() {
        // weekly discretionary = 700, spent = 800 -> spendable = -100
        let c = calc(
            income: 3100, // weekly discretionary = 3100/31*7 = 700
            mandatory: 0,
            variableSpend: 800,
            currentWeekVariableSpend: 800,
            daysInMonth: 31
        )
        #expect(c.spendable(for: .week) == -100)
        #expect(c.effectiveBudget(for: .week) == 700)
    }

    // MARK: - Safe to Spend / Upcoming Bills Deduction (Suggestion D)

    @Test func safeToSpendDeductsUpcomingUnpaidBillsFromLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 0,
            liquidCashAvailable: 1_000,
            spendingPlanMode: .safeToSpend,
            upcomingUnpaid: 300,
            daysInMonth: 30
        )
        // monthlyDiscretionary = 8000
        // safeCash = 1000 - 300 = 700
        // monthly budget = min(8000, 700 + 0) = 700
        // spendable = 700 - 0 = 700
        #expect(c.spendable(for: .month) == 700)
    }

    @Test func effectiveIncomeDecaysWhenKnownIncomeIsBelow30Percent() {
        // Day 20 of 30, knownIncome = $1,000 (which is < 5000 * 0.3 = 1500)
        // expected income decays from Day 15 to Day 30:
        // decay = 1.0 - (20-15)/(30-15) = 0.6667
        // expected = 5000 * 0.6667 = 3333.33
        // effectiveIncome = max(3333.33, 1000) = 3333.33
        let c = calc(
            income: 5000,
            knownIncome: 1000,
            liquidCashAvailable: 1000,
            dayOfMonth: 20,
            daysInMonth: 30
        )
        #expect(abs(c.effectiveIncome - 3333.33) < 0.1)
    }

    @Test func effectiveIncomeDoesNotDecayWhenKnownIncomeIsAbove30Percent() {
        // Day 20 of 30, knownIncome = $2,000 (which is >= 5000 * 0.3 = 1500)
        // no decay! effectiveIncome = max(5000, 2000) = 5000
        let c = calc(
            income: 5000,
            knownIncome: 2000,
            liquidCashAvailable: 1000,
            dayOfMonth: 20,
            daysInMonth: 30
        )
        #expect(c.effectiveIncome == 5000)
    }

    @Test func breakdownReconcilesWithCapAdjustments() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            variableSpend: 5_000,
            currentWeekVariableSpend: 2_000,
            todayVariableSpend: 55,
            liquidCashAvailable: 1_000, // Safe-to-Spend cash binds!
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .day)
        
        #expect(breakdown.steps.count == 2)
        #expect(breakdown.steps[0].title == "Start with today's room")
        #expect(breakdown.steps[1].title == "What you've spent today")
        
        // Sum of all steps MUST exactly match finalAmount
        let sum = breakdown.steps.map(\.amount).reduce(0, +)
        #expect(abs(sum - breakdown.finalAmount) < 0.01)
    }

    @Test func overspentDailyPeriodGoesNegative() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            variableSpend: 500,
            todayVariableSpend: 400, // daily budget is ~42.8, spent 400!
            liquidCashAvailable: 5_000,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        let spendable = c.spendable(for: .day)
        #expect(spendable < 0)
        #expect(abs(spendable - (c.budget(for: .day) - 400)) < 0.01)
    }

    @Test func weekOverspendingCappedByMonthOverspending() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            variableSpend: 15_568, // monthly spend
            currentWeekVariableSpend: 7_511, // weekly spend
            liquidCashAvailable: 2_281,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 31
        )
        // monthly discretionary = 9000
        // monthly remaining = 9000 - 15568 = -6568
        // weekly remaining without capping would be 2165 - 7511 = -5346 (wait, if monthlyRemainingBeforeThisWeek was 9000 - (15568 - 7511) = 9000 - 8057 = 943. So rawWeek budget is 943. So raw weekly remaining is 943 - 7511 = -6568).
        // Let's check that the weekly overspending matches monthly overspending and does not exceed it.
        #expect(abs(c.spendable(for: .week) - c.spendable(for: .month)) < 0.01)
    }

    @Test func weekSpanningMonthBoundaryDoesNotStarveWhenMonthOverspent() {
        let c = calc(
            income: 10_000,
            mandatory: 0,
            knownIncome: 10_000, // payroll lands, preventing paycheck illusion decay
            variableSpend: 15_000,
            currentWeekVariableSpend: 0,
            liquidCashAvailable: 5_000,
            spendingPlanMode: .safeToSpend,
            dayOfMonth: 30,
            daysInMonth: 30,
            daysElapsedInWeek: 1 // Sunday May 30th (last day of 30-day month)
        )
        // dailyDiscretionary = 10000 / 30 = 333.33
        // 1 day in current month (May), 6 days in next month (June)
        // May budget part capped at 0 because month is overspent.
        // June budget part uncapped: 6 * 333.333 = 2000.
        // So week budget should be exactly 2000.
        #expect(abs(c.budget(for: .week) - 2000.0) < 1.0)
        #expect(c.spendable(for: .week) == 0.0) // unspent week in overspent month resets to 0 remaining room
    }

    @Test func weekNegativeSpendableCappedByOverspentMonth() {
        let c = calc(
            income: 10_000,
            mandatory: 0,
            variableSpend: 15_000,
            currentWeekVariableSpend: 0,
            liquidCashAvailable: 2_000, // safe cash = 2000
            spendingPlanMode: .safeToSpend,
            dayOfMonth: 15,
            daysInMonth: 30,
            daysElapsedInWeek: 1
        )
        // monthly discretionary = 10000
        // safeCash = 2000
        // monthly budget = min(10000, 2000 + 15000) = 10000
        // monthly remaining = 10000 - 15000 = -5000
        // safeMonthlyRemaining < 0, but rawSpendable is 0, so max(0, -5000) = 0
        #expect(c.spendable(for: .week) == 0)
    }
}
