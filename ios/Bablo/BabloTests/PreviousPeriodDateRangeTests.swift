import Testing
import Foundation
@testable import Bablo

// Jan 1 2024 = Monday (verified: 2023 had 365 days, Jan 1 2023 was Sunday, +1 = Monday)
// 2024 is a leap year (Feb has 29 days)

@Suite struct PreviousPeriodDateRangeTests {

    // ISO 8601 calendar with UTC, same defaults as PreviousPeriodDateRange.compute()
    private var cal: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: comps)!
    }

    // MARK: - Previous week

    @Test func previousWeekOnMonday() {
        // Jan 8 2024 is Monday. Current week = Jan 8–14.
        // Previous week = Jan 1–7.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 8), calendar: cal)
        #expect(r.prevWeekStart == "2024-01-01")
        #expect(r.prevWeekEnd   == "2024-01-07")
    }

    @Test func previousWeekMidWeek() {
        // Jan 10 2024 is Wednesday — same calendar week as Jan 8.
        // Previous week should still be Jan 1–7.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 10), calendar: cal)
        #expect(r.prevWeekStart == "2024-01-01")
        #expect(r.prevWeekEnd   == "2024-01-07")
    }

    @Test func previousWeekOnSunday() {
        // Jan 7 2024 is Sunday — last day of the week containing Jan 1–7.
        // Previous week = Dec 25–31 2023.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 7), calendar: cal)
        #expect(r.prevWeekStart == "2023-12-25")
        #expect(r.prevWeekEnd   == "2023-12-31")
    }

    @Test func previousWeekOnFirstDayOfYear() {
        // Jan 1 2024 is Monday — first day of its week.
        // Previous week = Dec 25–31 2023.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 1), calendar: cal)
        #expect(r.prevWeekStart == "2023-12-25")
        #expect(r.prevWeekEnd   == "2023-12-31")
    }

    // MARK: - Previous month

    @Test func previousMonthMidYear() {
        // May 2024 → previous month = April 2024 (30 days)
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 5, day: 15), calendar: cal)
        #expect(r.prevMonthStart == "2024-04-01")
        #expect(r.prevMonthEnd   == "2024-04-30")
    }

    @Test func previousMonthJanuaryWrapsToDecember() {
        // January → previous month = December of previous year
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 15), calendar: cal)
        #expect(r.prevMonthStart == "2023-12-01")
        #expect(r.prevMonthEnd   == "2023-12-31")
    }

    @Test func previousMonthLeapYear() {
        // March 2024 → previous month = February 2024 (leap year, 29 days)
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 3, day: 1), calendar: cal)
        #expect(r.prevMonthStart == "2024-02-01")
        #expect(r.prevMonthEnd   == "2024-02-29")
    }

    @Test func previousMonthNonLeapYear() {
        // March 2023 → previous month = February 2023 (non-leap, 28 days)
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2023, month: 3, day: 1), calendar: cal)
        #expect(r.prevMonthStart == "2023-02-01")
        #expect(r.prevMonthEnd   == "2023-02-28")
    }
}
