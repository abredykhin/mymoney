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

        // Room delta is the change in the WEEKLY PACE, not the raw spend delta. Spending $42
        // less this week lifts the weekly pace by $42 × 7/daysRemaining (= 7/16 here) ≈ $18.38
        // — sane and lump-safe. NOTE: currentRoom is the pace, which the cushion deliberately
        // keeps even though the hero headline (spendable) is now net of this week's spend — the
        // cushion compares spending PACE period-over-period, a different lens than "left to spend".
        #expect(snapshot?.currentRoom == c.unflooredPace(for: .week, remaining: c.spendable(for: .month)))
        #expect(abs((snapshot?.roomDelta ?? -1) - 18.375) < 0.01)
        // previousRoom = currentRoom − roomDelta identity (display relies on it).
        #expect(abs((snapshot?.previousRoom ?? 0) - ((snapshot?.currentRoom ?? 0) - (snapshot?.roomDelta ?? 0))) < 0.001)
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

        // Daily pace impact of spending $32 less today: $32 × 1/daysRemaining (=1/17) ≈ $1.88.
        #expect(snapshot != nil)
        #expect(abs((snapshot?.roomDelta ?? -1) - 1.882) < 0.01)
        #expect(snapshot?.hasMoreRoom == true)
    }

    @Test func cushionSnapshotDeltaMatchesDisplayedRoundedSpendRows() throws {
        let c = calc(todayVariableSpend: 73.72, prevDay: 60.25)

        let snapshot = try #require(HeroCushionSnapshot(calculator: c, period: .day))

        // Spent ~$13 more today → daily pace dips by ~$13/17 ≈ $0.79 (negative = less room).
        // The card still appears (spend moved ≥ $1); the headline is the pace delta.
        #expect(abs(snapshot.roomDelta - (-0.792)) < 0.01)
        #expect(abs(snapshot.previousRoom - (snapshot.currentRoom - snapshot.roomDelta)) < 0.001)
        #expect(snapshot.hasMoreRoom == false)
    }

    @Test func cushionVerdictHeadlineShowsStillOverWhenCurrentRoomIsNegativeButImproved() throws {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 4_000,
            prevMonth: 22_676,
            daysInMonth: 31
        )
        let snapshot = try #require(HeroCushionSnapshot(calculator: c, period: .month))

        #expect(snapshot.currentRoom < 0)
        #expect(snapshot.roomDelta > 0)
        #expect(CushionVerdictCopy.headline(for: snapshot, comparisonName: "last month") == "Still over, but better than last month.")
    }

    @Test func cushionDriversInvertSpendDeltaIntoRoomDelta() {
        let items = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 49, transactionCount: 3, percentOfTotal: 0.4, previousAmount: 80),
            CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 48, transactionCount: 2, percentOfTotal: 0.3, previousAmount: 30),
            CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 28, transactionCount: 2, percentOfTotal: 0.2, previousAmount: 40),
        ]

        let drivers = HeroCushionDriver.drivers(from: items)

        #expect(drivers.map(\.roomDelta) == [31, -18, 12])
        #expect(drivers.map(\.spendDelta) == [-31, 18, -12])
        #expect(drivers[0].kind == .grew)
        #expect(drivers[1].kind == .shrank)
    }

    @Test func cushionDriverBarSideFollowsSpendDirection() throws {
        let items = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 49, transactionCount: 3, percentOfTotal: 0.4, previousAmount: 80),
            CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 48, transactionCount: 2, percentOfTotal: 0.3, previousAmount: 30),
        ]

        let drivers = HeroCushionDriver.drivers(from: items)
        let eats = try #require(drivers.first { $0.bucket == SpendingBucket.category(.eatsOut) })
        let shopping = try #require(drivers.first { $0.bucket == SpendingBucket.category(.shopping) })

        #expect(eats.barSide == .left)
        #expect(shopping.barSide == .right)
    }

    @Test func cushionDriverKeepsActualSpendAmountsWhenScaledForRoomImpact() throws {
        let items = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 48, transactionCount: 3, percentOfTotal: 0.4, previousAmount: 79),
        ]

        let driver = try #require(HeroCushionDriver.drivers(from: items, scale: 0.5).first)

        #expect(driver.currentAmount == 48)
        #expect(driver.previousAmount == 79)
        #expect(driver.spendDelta == -31)
        #expect(driver.roomDelta == 16)
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

    /// Week/day breakdown is month-derived so the period number is explicable: step 1 is the
    /// month budget, step 2 subtracts spend from earlier this month (landing on the pool as it
    /// stood at the start of the period), step 3 holds back the other days' share — leaving this
    /// period's allowance — and step 4 subtracts this period's own spend to reach the pace.
    @Test func breakdownWeekIsMonthDerivedChain() {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 900,
            currentWeekVariableSpend: 210,
            daysInMonth: 30
        )
        let bd = HeroBudgetBreakdownCalculator(calculator: c, period: .week)
        let monthBudget = c.effectiveBudget(for: .month)
        let monthSpent = c.spentSoFar(for: .month)
        let weekSpent = c.spentSoFar(for: .week)
        let pace = c.spendable(for: .week)

        #expect(bd.steps.count == 4)
        #expect(bd.steps[0].title == "This month's budget")
        #expect(abs(bd.steps[0].amount - monthBudget) < 0.01)
        #expect(bd.steps[1].title == "Spent earlier this month")
        #expect(abs(bd.steps[1].amount - (-(monthSpent - weekSpent))) < 0.01)
        #expect(bd.steps[2].title == "Saved for the rest of the month")
        #expect(bd.steps[3].title == "Spent this week")
        #expect(abs(bd.steps[3].amount - (-weekSpent)) < 0.01)
        #expect(abs(bd.steps[3].afterAmount - pace) < 0.01)
        #expect(bd.steps[3].transactionSource == .variableSpend)
        // The period-spend card is the last step and carries the period's category sub-rows.
        #expect(bd.spendStepNumber == 4)
        // Step 1 unpacks the pool into Total income − Obligations.
        #expect(bd.contextRows.count == 2)
        #expect(bd.contextRows[0].title == "Total income")
        #expect(bd.contextRows[1].title == "Obligations")
        #expect(abs(bd.steps.map(\.amount).reduce(0, +) - pace) < 0.01)
    }

    /// When spending barely moved versus the prior period (room delta rounds to $0) the pill is
    /// hidden entirely rather than showing a noisy "about the same" chip.
    @Test func deltaChipDayHiddenWhenRoomBarelyMoves() {
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 500,
            todayVariableSpend: 15,
            prevDay: 10,
            daysInMonth: 31
        )
        #expect(c.deltaChip(for: .day) == nil)
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

        #expect(breakdown.contextRows.isEmpty)
        #expect(!breakdown.isCashCapped)
        #expect(breakdown.steps.first?.title == "Net cash on hand")
        #expect(breakdown.steps.count == 3)
    }

    @Test func breakdownMonthlyIncomeModeHasThreeSteps() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 500
        )

        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .month)

        #expect(!breakdown.isCashCapped)
        #expect(breakdown.steps.count == 4)
        #expect(breakdown.steps[0].title == "Income this month")
        #expect(breakdown.steps[1].title == "Monthly obligations")
        #expect(breakdown.steps[2].title == "Goals set aside")
        #expect(breakdown.steps[3].title == "What you've spent this month")
        #expect(abs(breakdown.steps.map(\.amount).reduce(0, +) - c.spendable(for: .month)) < 0.01)
    }

    @Test func breakdownMonthlyIncomeModeNoMandatoryHasTwoSteps() {
        let c = calc(income: 5_000, mandatory: 0, variableSpend: 300)
        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .month)

        #expect(breakdown.steps.count == 3)
        #expect(breakdown.steps[0].title == "Income this month")
        #expect(breakdown.steps[1].title == "Goals set aside")
        #expect(breakdown.steps[2].title == "What you've spent this month")
        #expect(abs(breakdown.steps.map(\.amount).reduce(0, +) - c.spendable(for: .month)) < 0.01)
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
        // single-pool, net-of-this-week's-spend:
        // poolTotal = 3000, variableSpend 500 -> poolRemaining = 2500, daysRemaining = 17.
        // weekBudget = min(2733, (2500+233)/17 * 7) = 1125.35; spendable = 1125.35 - 233 = 892.35.
        let weekSpent = 233.0
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 500,
                     currentWeekVariableSpend: weekSpent, daysInMonth: 31)
        #expect(abs(c.spendable(for: .week) - 892.35) < 0.05)
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
            knownIncome: 10_000,
            variableSpend: 1_000,
            liquidCashAvailable: 3_500,
            spendingPlanMode: .safeToSpend
        )
        #expect(c.totalDiscretionary(for: .month) == 3_500)
        #expect(c.spendable(for: .month) == 3_500)
    }

    @Test func safeToSpendCapsWeekByLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            knownIncome: 10_000,
            variableSpend: 0,
            currentWeekVariableSpend: 0,
            liquidCashAvailable: 500,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        // monthly pool = 500. daysRemaining = 30 - 15 + 1 = 16.
        // dailyPace = 500 / 16 = 31.25. weeklyPace = min(500, 31.25 * 7) = 218.75.
        #expect(abs(c.spendable(for: .week) - 218.75) < 0.05)
    }

    @Test func safeToSpendCapsDayByLiquidCash() {
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            knownIncome: 10_000,
            todayVariableSpend: 0,
            liquidCashAvailable: 100,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        // monthly pool = 100. daysRemaining = 16. dailyPace = 100 / 16 = 6.25.
        #expect(abs(c.spendable(for: .day) - 6.25) < 0.01)
    }

    @Test func safeToSpendFallsBackToMonthlyPlanWhenCashIsUnavailable() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            variableSpend: 1_000,
            liquidCashAvailable: nil,
            spendingPlanMode: .safeToSpend
        )
        #expect(c.spendable(for: .month) == 0.0)
    }

    /// When liquid cash < plan remaining and nothing has been spent yet,
    /// the fill should be 100 % (full tank), not 6% (liquid/plan ratio).
    @Test func safeToSpendFillIsFullAtStartOfMonthWhenNothingSpent() {
        let c = calc(
            income: 10_000,
            mandatory: 2_000,
            knownIncome: 10_000,
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
            knownIncome: 10_000,
            variableSpend: 500,
            liquidCashAvailable: 3_500,
            spendingPlanMode: .safeToSpend
        )
        #expect(c.fillTarget(for: .month) == 1.0)
    }

    /// Negative liquid balance (more debt than cash) must not show as available.
    @Test func negativeLiquidCashFloorsSpendableToZero() {
        let c = calc(
            income: 5_000,
            mandatory: 1_000,
            knownIncome: 5_000,          // paycheck already in; no pending income to soften the floor
            variableSpend: 0,
            liquidCashAvailable: -200,   // net negative: credit > depository
            spendingPlanMode: .safeToSpend
        )
        #expect(c.spendable(for: .month) == 0)
    }

    // Obsolete: cash-only mode does not credit pending paychecks.

    /// Once the paycheck has landed (knownIncome high), there is no pending income to credit and
    /// the cushion reverts to the pure liquid-cash ceiling.
    @Test func safeToSpendRevertsToCashCapAfterPaycheckLands() {
        let c = calc(
            income: 9_000,
            mandatory: 1_000,
            knownIncome: 9_000,          // fully received → no pending income
            variableSpend: 0,
            liquidCashAvailable: 400,
            spendingPlanMode: .safeToSpend,
            dayOfMonth: 20,
            daysInMonth: 30
        )
        // cushion = max(0, 400 + 0 − 0) = 400 → capped well below discretionary (8_000)
        #expect(abs(c.spendable(for: .month) - 400) < 0.01)
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
        // prev week $300, this week $150 → more room to spend.
        let c = calc(variableSpend: 500, currentWeekVariableSpend: 150, prevWeek: 300)
        let chip = c.deltaChip(for: .week)
        #expect(chip?.label.hasSuffix("more vs last wk") == true)
        #expect(chip?.hasMoreRoom == true)
    }

    @Test func deltaLabelWeekNegativeWhenSpentMore() {
        // prev week $100, this week $300 → less room to spend.
        let c = calc(variableSpend: 500, currentWeekVariableSpend: 300, prevWeek: 100)
        let chip = c.deltaChip(for: .week)
        #expect(chip?.label.hasSuffix("less vs last wk") == true)
        #expect(chip?.hasMoreRoom == false)
    }

    /// The chip is the change in the WEEKLY PACE (pace-based room delta from the cushion
    /// snapshot), not the raw week-over-week spend delta. poolRemaining 2500, weekly pace
    /// 2500/17*7≈1029; if last week's $300 had repeated this week ($250) the pool would be
    /// 2450 → pace 1009. Room delta ≈ +$21.
    @Test func deltaLabelWeekUsesActualCurrentWeekSpend() {
        let c = calc(variableSpend: 500, currentWeekVariableSpend: 250, prevWeek: 300)
        let label = c.deltaLabel(for: .week)
        #expect(label == "$21 more vs last wk")
    }

    @Test func deltaLabelMonthPositive() {
        // prev month $1200, curr month $500 → more room.
        let c = calc(variableSpend: 500, prevMonth: 1200)
        let label = c.deltaLabel(for: .month)
        #expect(label == "$700 more vs last mo")
    }

    @Test func deltaLabelMonthNegative() {
        // prev month $400, curr month $500 → less room.
        let c = calc(variableSpend: 500, prevMonth: 400)
        let label = c.deltaLabel(for: .month)
        #expect(label == "$100 less vs last mo")
    }

    @Test func deltaLabelNilWhenBothZero() {
        let c = calc(variableSpend: 0, currentWeekVariableSpend: 0, prevWeek: 0, prevMonth: 0)
        #expect(c.deltaLabel(for: .week) == nil)
        #expect(c.deltaLabel(for: .month) == nil)
    }

    @Test func deltaLabelNotNilWhenOnlyCurrentIsNonZero() {
        // prev = 0, curr > 0 → negative delta label is still shown
        let c = calc(variableSpend: 200, prevMonth: 0)
        let chip = c.deltaChip(for: .month)
        #expect(chip != nil)
        #expect(chip?.hasMoreRoom == false)
    }

    @Test func deltaLabelShownWhenOnlyPreviousPeriodHasSpend() {
        let c = calc(variableSpend: 0, prevMonth: 25_878)
        #expect(c.deltaLabel(for: .month) == "$26K more vs last mo")
    }

    /// Delta label must appear when actual income is received (knownIncome > 0),
    /// even if the user has not yet set up a profile with monthlyIncome.
    @Test func deltaLabelShownWhenOnlyKnownIncomeExists() {
        // Regression: previously the guard was `monthlyIncome > 0`, which hid the
        // delta for new users who have real paychecks but no profile budget set.
        // income=0, knownIncome=6000, mandatory=2000 → monthlyDiscretionary=4000
        // prevMonth=3000 is within budget → delta label is shown
        let c = calc(income: 0, knownIncome: 6000, variableSpend: 1000, prevMonth: 3000)
        let chip = c.deltaChip(for: .month)
        #expect(chip != nil, "delta must be visible when effectiveIncome > 0")
        #expect(chip?.hasMoreRoom == true)   // prev(3000) > curr(1000) → more room
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

    // Day chips are the change in the DAILY PACE (pool/days-remaining), so a small spend
    // gap moves the pace by gap/daysRemaining — not the raw spend gap. With poolRemaining
    // 2500 and 17 days left, today $0 vs yesterday $42 nudges the daily pace by ~$2.
    @Test func deltaLabelDayPositiveWhenSpentLessThanYesterday() {
        let c = calc(todayVariableSpend: 0, prevDay: 42)
        #expect(c.deltaLabel(for: .day) == "$2 more vs yesterday")
    }

    @Test func deltaLabelDayNegativeWhenSpentMoreThanYesterday() {
        let c = calc(todayVariableSpend: 64, prevDay: 12)
        #expect(c.deltaLabel(for: .day) == "$3 less vs yesterday")
    }

    /// Chip rounds the pace-based room delta (not the raw spend delta). poolRemaining 1500,
    /// 17 days left → pace 88.24; had today's $73.72 instead been yesterday's $60.25 the pace
    /// would be 89.03, so the room delta is ≈ -$1.
    @Test func deltaLabelDayUsesPaceBasedRoomDelta() {
        let c = calc(
            income: 2_000,
            mandatory: 0,
            todayVariableSpend: 73.72,
            prevDay: 60.25
        )

        #expect(c.deltaLabel(for: .day) == "$1 less vs yesterday")
    }

    @Test func deltaLabelWeekShownWhenCurrentWeekIsZeroButPreviousWeekHasSpend() {
        // Weekly pace room delta, not raw $88: pool 3000, 17 days left → pace 1235; if last
        // week's $88 had repeated, pool 2912 → pace 1199. Room delta ≈ +$36.
        let c = calc(variableSpend: 0, currentWeekVariableSpend: 0, prevWeek: 88)
        #expect(c.deltaLabel(for: .week) == "$36 more vs last wk")
    }

    /// The pill compares spend period over period, so it should still appear when
    /// last period exceeded the current budget model.
    @Test func deltaLabelMonthShownWhenPreviousMonthExceededBudget() {
        // income=10990, mandatory=4366 → discretionary=6624
        // prevMonthSpend=30900 > 6624, but spend comparison is still meaningful.
        let c = calc(income: 10_990, mandatory: 4_366, variableSpend: 5_990, prevMonth: 30_900)
        #expect(c.deltaLabel(for: .month) == "$25K more vs last mo")
    }

    /// Previous month within budget — delta is a valid remaining-budget comparison and must show.
    @Test func deltaLabelMonthShownWhenPreviousMonthWithinBudget() {
        // income=10990, mandatory=4366 → discretionary=6624
        // prevMonthSpend=4000 <= 6624, currSpend=5990 → less room.
        let c = calc(income: 10_990, mandatory: 4_366, variableSpend: 5_990, prevMonth: 4_000)
        #expect(c.deltaLabel(for: .month) != nil)
    }

    /// Same behavior for weeks: the chip remains a real week-over-week comparison.
    @Test func deltaLabelWeekShownWhenPreviousWeekExceededBudget() {
        // Weekly pace room delta: pool 2500, 17 days left → pace 1029; had last week's $1500
        // repeated this week the pool would be 1200 → pace 494. Room delta ≈ +$535.
        let c = calc(income: 5_000, mandatory: 2_000, currentWeekVariableSpend: 200, prevWeek: 1_500)
        #expect(c.deltaLabel(for: .week) == "$535 more vs last wk")
    }

    @Test func deltaLabelMonthCurrentInRedImprovedUsesInTheRedCopy() {
        // Month is overspent (poolRemaining < 0), but last month was much deeper in the red.
        let c = calc(
            income: 5_000,
            mandatory: 2_000,
            variableSpend: 4_000,
            prevMonth: 24_000
        )
        #expect(c.spendable(for: .month) < 0)
        #expect(c.deltaLabel(for: .month) == "$20K less in the red vs last mo")
    }

    /// Regression for the chip/cushion-sheet split: when a one-off lump lands yesterday (e.g. a
    /// $4,817 spousal-support wire — legitimate spend that stays counted), the chip must read the
    /// SAME pace-based room delta the cushion sheet shows, not the raw day-over-day spend delta
    /// (~+$4,984, which used to render as a nonsensical "+$5K" beside a $40 daily pace).
    @Test func deltaLabelDayMatchesCushionSnapshotNotRawSpend() {
        let c = calc(
            income: 10_990,
            mandatory: 4_613,
            variableSpend: 5_268,
            todayVariableSpend: 3,
            prevDay: 4_987,
            dayOfMonth: 3,
            daysInMonth: 30
        )
        let snapshot = HeroCushionSnapshot(calculator: c, period: .day)
        #expect(snapshot != nil)
        let roomDelta = Int(snapshot!.roomDelta.rounded())
        // Chip equals the snapshot's room delta (the cushion sheet headline)…
        #expect(c.deltaLabel(for: .day) == "$\(roomDelta) more vs yesterday")
        // …and is on the daily-pace scale: the raw $4,984 day-over-day spend gap spread across
        // the 28 days left this month ≈ $178, far below the raw spend delta (which would have
        // rendered as a nonsensical "+$5K" beside the day's pace).
        let rawSpendGap = 4_987 - 3
        #expect(roomDelta == rawSpendGap / 28)            // pace-scaled, == 178
        #expect(roomDelta < rawSpendGap / 10)             // nowhere near the raw spend delta
    }

    /// A received one-off inflow (e.g. a brokerage credit counted as extra income) must not
    /// inflate the "Expected paycheck still to come" figure: effectiveIncome already includes
    /// it, so expectedIncomeStillToCome subtracts both known AND extra, leaving just the
    /// unreceived projected salary. Regression for the "$17,455 expected paycheck" report.
    @Test func expectedPaycheckExcludesReceivedOneOffIncome() {
        let c = calc(income: 10_990, mandatory: 4_613, knownIncome: 0, extraIncome: 6_464, dayOfMonth: 5)
        #expect(c.effectiveIncome == 17_454)            // projected 10,990 + received one-off 6,464
        #expect(c.expectedIncomeStillToCome == 10_990)  // only the projected salary not yet received
    }

    // MARK: - Monthly cap: week/day cannot exceed what's left for the month

    /// Core regression: when the user is near month-end with little monthly budget left,
    /// the weekly remaining must not exceed the monthly remaining.
    @Test func weekSpendableCannotExceedMonthlyRemaining() {
        // Monthly discretionary = $6,626, spent $5,846 → $780 left for the month.
        // weekBudget = min(791, (780+11)/17 * 7) = 325.71; spendable = 325.71 − 11 = 314.71 ≤ 780.
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
        #expect(abs(c.spendable(for: .week) - 314.71) < 0.05)
    }

    @Test func dailyBudgetIsWeeklyBudgetDividedBy7() {
        let c = calc(
            income: 6_626,
            mandatory: 0,
            variableSpend: 6_576,
            todayVariableSpend: 0,
            daysInMonth: 31
        )
        let expectedWeekly = c.budget(for: .week)
        let expectedDaily  = expectedWeekly / 7
        #expect(abs(c.budget(for: .day) - expectedDaily) < 0.01)
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
        // Weekly pace is 2800 / 17 * 7 = 1152.94
        let c = calc(
            income: 3_000,
            mandatory: 0,
            variableSpend: 200,
            currentWeekVariableSpend: 0,
            daysInMonth: 31
        )
        #expect(abs(c.spendable(for: .week) - 1152.94) < 0.05)
    }

    @Test func monthSpendableIsNeverAffectedByCap() {
        // The monthly cap only applies to sub-month periods; month itself is unchanged.
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 4000)
        #expect(c.spendable(for: .month) == -1000)
    }

    @Test func weekAndMonthConvergeAtMonthEnd() {
        // When the remaining month is shorter than a week (e.g., 3 days left),
        // the weekly spendable is capped well below the weekly budget.
        // Monthly = $3,000, spent $2,900 → $100 left.
        // Week spendable = min(100, 33.33 * 7) = $100.
        let c = calc(
            income: 3_000,
            mandatory: 0,
            variableSpend: 2_900,
            currentWeekVariableSpend: 0,
            dayOfMonth: 29,
            daysInMonth: 31
        )
        #expect(abs(c.spendable(for: HeroPeriod.week) - 100) < 0.01)
        #expect(abs(c.spendable(for: HeroPeriod.month) - 100) < 0.01)
    }

    @Test func weeklyCap_NotTriggeredWhenWeeklyIsAlreadyBelowMonthly() {
        let weeklySpend = 200.0
        let c = calc(
            income: 5_000,
            mandatory: 0,
            variableSpend: 100,
            currentWeekVariableSpend: weeklySpend,
            daysInMonth: 31
        )
        // pool = 4900. weekBudget = min(5100, (4900+200)/17 * 7) = 2100; spendable = 2100 − 200 = 1900.
        #expect(abs(c.spendable(for: .week) - 1900.0) < 0.05)
    }

    // MARK: - Effective budget (denominator for "X of Y" display)

    /// When no constraint is binding, effectiveBudget == totalDiscretionary for the period.
    @Test func effectiveBudgetEqualsDiscretionaryWhenNoCap() {
        let c = calc(income: 5_000, mandatory: 0, variableSpend: 100,
                     currentWeekVariableSpend: 50, daysInMonth: 31)
        let weekBudget = 5_000.0 / 31.0 * 7.0
        #expect(abs(c.effectiveBudget(for: .week) - weekBudget) < 0.01)
    }

    /// Under the new single-pool model, denominators are stable: effectiveBudget = poolTotal * daysInPeriod / daysInMonth.
    @Test func effectiveBudgetIsStableWhenMonthlyCaps() {
        let c = calc(
            income: 6_626,
            mandatory: 0,
            variableSpend: 5_846,
            currentWeekVariableSpend: 203,
            daysInMonth: 31
        )
        #expect(abs(c.effectiveBudget(for: .week) - 1496.19) < 0.05)
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

    @Test func weekGoesNegativeWhenOverspent() {
        // Month overspent (poolRemaining −900) and $800 spent this week. The week's budget floors
        // at $0 (poolAtWeekStart −100 → 0), so "safe to spend this week" = 0 − 800 = −800
        // ("over by $800 this week"), mirroring how .month goes negative when overspent.
        let c = calc(
            income: 3100,
            mandatory: 0,
            variableSpend: 4000,
            currentWeekVariableSpend: 800,
            daysInMonth: 31
        )
        #expect(abs(c.spendable(for: .week) - (-800)) < 0.05)
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
        #expect(c.spendable(for: .month) == 700.0)
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
            liquidCashAvailable: 1_000,
            spendingPlanMode: .safeToSpend,
            daysInMonth: 30
        )
        let breakdown = HeroBudgetBreakdownCalculator(calculator: c, period: .day)

        // Cash mode (safeToSpend): the month pool is cash-on-hand and doesn't net spend, so the
        // month-derived chain is 3 steps — month budget → held for the other days → spent today —
        // reconciling to the pace. (No "spent earlier this month" step; that's income mode only.)
        #expect(breakdown.steps.count == 3)
        #expect(breakdown.steps[0].title == "This month's budget")
        #expect(breakdown.steps[1].title == "Saved for the rest of the month")
        #expect(breakdown.steps[2].title == "Spent today")

        // Sum of all steps MUST exactly match finalAmount
        let sum = breakdown.steps.map(\.amount).reduce(0, +)
        #expect(abs(sum - breakdown.finalAmount) < 0.01)
    }

    @Test func overspentDailyPeriodGoesNegative() {
        // Month overspent (poolRemaining −6000); $400 spent today. Day budget floors at $0, so
        // "safe to spend today" = 0 − 400 = −400 ("over by $400 today").
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            variableSpend: 15_000,
            todayVariableSpend: 400,
            liquidCashAvailable: 5_000,
            spendingPlanMode: .monthlyPlan,
            daysInMonth: 30
        )
        let spendable = c.spendable(for: .day)
        #expect(abs(spendable - (-400)) < 0.05)
    }

    @Test func weekOverspendingGoesNegative() {
        // A $7,511 lump this week against a tiny week budget (≈$388) → "over by ~$7,123 this week".
        // The user wants this period spend reflected even when it's a lump.
        let c = calc(
            income: 10_000,
            mandatory: 1_000,
            variableSpend: 15_568,
            currentWeekVariableSpend: 7_511,
            liquidCashAvailable: 2_281,
            spendingPlanMode: .monthlyPlan,
            daysInMonth: 31
        )
        #expect(abs(c.spendable(for: .week) - (-7122.71)) < 0.1)
    }

    @Test func weekSpanningMonthBoundaryDoesNotStarveWhenMonthOverspent() {
        let c = calc(
            income: 10_000,
            mandatory: 0,
            knownIncome: 10_000,
            variableSpend: 15_000,
            currentWeekVariableSpend: 0,
            liquidCashAvailable: 5_000,
            spendingPlanMode: .safeToSpend,
            dayOfMonth: 30,
            daysInMonth: 30,
            daysElapsedInWeek: 1
        )
        #expect(abs(c.budget(for: HeroPeriod.week) - 1166.67) < 1.0)
        #expect(c.spendable(for: HeroPeriod.week) == 5000.0)
    }

    @Test func weekNegativeSpendableFloorsAtZero() {
        let c = calc(
            income: 10_000,
            mandatory: 0,
            variableSpend: 15_000,
            currentWeekVariableSpend: 0,
            liquidCashAvailable: 2_000,
            spendingPlanMode: .monthlyPlan,
            dayOfMonth: 15,
            daysInMonth: 30,
            daysElapsedInWeek: 1
        )
        #expect(c.spendable(for: .week) == 0)
    }
}
