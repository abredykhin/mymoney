import Testing
@testable import Bablo

@Suite("HeroBudgetCalculator")
struct HeroBudgetCalculatorTests {

    // MARK: - Helpers

    private func calc(
        income: Double = 5000,
        mandatory: Double = 2000,
        variableSpend: Double = 500,
        prevWeek: Double = 300,
        prevMonth: Double = 1200,
        dayOfMonth: Int = 15,
        daysInMonth: Int = 31
    ) -> HeroBudgetCalculator {
        HeroBudgetCalculator(
            monthlyIncome: income,
            monthlyMandatoryExpenses: mandatory,
            variableSpend: variableSpend,
            previousWeekVariableSpend: prevWeek,
            previousMonthVariableSpend: prevMonth,
            dayOfMonth: dayOfMonth,
            daysInMonth: daysInMonth
        )
    }

    // MARK: - Monthly discretionary

    @Test func monthlyDiscretionaryPositive() {
        let c = calc(income: 5000, mandatory: 2000)
        #expect(c.monthlyDiscretionary == 3000)
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
        // $3000/31 * 7 = $677.41...
        let c = calc(income: 5000, mandatory: 2000, daysInMonth: 31)
        let expected = 3000.0 / 31.0 * 7.0
        #expect(abs(c.weeklyDiscretionary - expected) < 0.001)
    }

    @Test func weeklyDiscretionaryZeroDaysInMonthGuard() {
        let c = calc(income: 5000, mandatory: 2000, daysInMonth: 0)
        #expect(c.weeklyDiscretionary == 0)
    }

    // MARK: - Spent so far

    @Test func monthlySpentSoFarIsVariableSpend() {
        let c = calc(variableSpend: 750)
        #expect(c.spentSoFar(for: .month) == 750)
    }

    @Test func weeklySpentSoFarProration() {
        // $500 spent over 15 days of month → (500/15)*7 = $233.33
        let c = calc(variableSpend: 500, dayOfMonth: 15)
        let expected = (500.0 / 15.0) * 7.0
        #expect(abs(c.spentSoFar(for: .week) - expected) < 0.001)
    }

    @Test func weeklySpentSoFarZeroDayGuard() {
        let c = calc(variableSpend: 500, dayOfMonth: 0)
        #expect(c.spentSoFar(for: .week) == 0)
    }

    // MARK: - Spendable

    @Test func spendableMonthNothingSpent() {
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 0)
        #expect(c.spendable(for: .month) == 3000)
    }

    @Test func spendableMonthOverBudgetFloorsToZero() {
        let c = calc(income: 3000, mandatory: 2000, variableSpend: 2000)
        #expect(c.spendable(for: .month) == 0)
    }

    @Test func spendableWeekPositive() {
        // weekly discretionary = 3000/31*7 ≈ 677.42
        // weekly spent = 500/15*7 ≈ 233.33
        // spendable ≈ 444.09
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 500, dayOfMonth: 15, daysInMonth: 31)
        let disc = 3000.0 / 31.0 * 7.0
        let spent = 500.0 / 15.0 * 7.0
        let expected = disc - spent
        #expect(abs(c.spendable(for: .week) - expected) < 0.001)
    }

    // MARK: - Fill target

    @Test func fillTargetNormalCase() {
        // 50% spent → fillTarget = 0.5
        let c = calc(income: 4000, mandatory: 2000, variableSpend: 1000, dayOfMonth: 15, daysInMonth: 30)
        #expect(abs(c.fillTarget(for: .month) - 0.5) < 0.001)
    }

    @Test func fillTargetClampsToMinimum() {
        // fully spent → would be 0, clamped to 0.02
        let c = calc(income: 3000, mandatory: 2000, variableSpend: 1500)
        #expect(c.fillTarget(for: .month) == 0.02)
    }

    @Test func fillTargetClampsToMaximum() {
        // nothing spent → 1.0
        let c = calc(income: 5000, mandatory: 2000, variableSpend: 0)
        #expect(c.fillTarget(for: .month) == 1.0)
    }

    @Test func fillTargetZeroIncomeFallsToMinimum() {
        let c = calc(income: 0, mandatory: 0, variableSpend: 0)
        #expect(c.fillTarget(for: .month) == 0.02)
        #expect(c.fillTarget(for: .week) == 0.02)
    }

    // MARK: - Delta label

    @Test func deltaLabelWeekPositiveWhenSpentLess() {
        // prev week $300, curr week ≈ $233 → saved ~$67 → "+$67 vs last wk"
        let c = calc(variableSpend: 500, prevWeek: 300, dayOfMonth: 15)
        let label = c.deltaLabel(for: .week)
        #expect(label != nil)
        #expect(label!.hasPrefix("+"))
        #expect(label!.hasSuffix("vs last wk"))
    }

    @Test func deltaLabelWeekNegativeWhenSpentMore() {
        // prev week $100, curr week ≈ $233 → overspent → "-$133 vs last wk"
        let c = calc(variableSpend: 500, prevWeek: 100, dayOfMonth: 15)
        let label = c.deltaLabel(for: .week)
        #expect(label != nil)
        #expect(label!.hasPrefix("-"))
        #expect(label!.hasSuffix("vs last wk"))
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
        let c = calc(variableSpend: 0, prevWeek: 0, prevMonth: 0, dayOfMonth: 15)
        #expect(c.deltaLabel(for: .week) == nil)
        #expect(c.deltaLabel(for: .month) == nil)
    }

    @Test func deltaLabelNotNilWhenOnlyCurrentIsNonZero() {
        // prev = 0, curr > 0 → should still produce a label (negative)
        let c = calc(variableSpend: 200, prevMonth: 0)
        let label = c.deltaLabel(for: .month)
        #expect(label != nil)
        #expect(label!.hasPrefix("-"))
    }
}
