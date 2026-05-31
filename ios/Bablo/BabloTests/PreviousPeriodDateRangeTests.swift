import Testing
import Foundation
@testable import Bablo

// Known reference days (verified against Gregorian calendar):
// Jan 1  2024 = Monday
// Jan 7  2024 = Sunday
// Jan 8  2024 = Monday
// Jan 10 2024 = Wednesday
// May 24 2026 = Sunday
// May 25 2026 = Monday

@Suite struct PreviousPeriodDateRangeTests {

    // MARK: - Calendar helpers

    /// ISO 8601 (Monday-start) with UTC — same as the old hard-coded default.
    /// Tests that pass this calendar explicitly verify backward-compatible behavior.
    private func isoUTC() -> Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Sunday-start Gregorian with local timezone — same as Calendar.current in the US.
    /// Tests that pass this calendar verify the locale-aware behavior users expect.
    private func sundayStartLocal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1  // 1 = Sunday
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func mondayStartLocal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2  // 2 = Monday
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.timeZone = calendar.timeZone
        return calendar.date(from: comps)!
    }

    // MARK: - ISO UTC (backward-compat)

    @Test func previousWeekOnMonday_ISO() {
        // Jan 8 2024 is Monday. Current ISO week = Jan 8–14.
        // Previous week = Jan 1–7.
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 8, calendar: cal), calendar: cal)
        #expect(r.prevWeekStart == "2024-01-01")
        #expect(r.prevWeekEnd   == "2024-01-07")
    }

    @Test func previousWeekMidWeek_ISO() {
        // Jan 10 2024 is Wednesday — same ISO week as Jan 8.
        // Previous week should still be Jan 1–7.
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 10, calendar: cal), calendar: cal)
        #expect(r.prevWeekStart == "2024-01-01")
        #expect(r.prevWeekEnd   == "2024-01-07")
    }

    @Test func previousWeekOnSunday_ISO() {
        // In ISO weeks (Mon-start), Jan 7 2024 (Sunday) is the LAST day of the Jan 1–7 week.
        // Previous week = Dec 25–31 2023.
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 7, calendar: cal), calendar: cal)
        #expect(r.prevWeekStart == "2023-12-25")
        #expect(r.prevWeekEnd   == "2023-12-31")
    }

    @Test func previousWeekOnFirstDayOfYear_ISO() {
        // Jan 1 2024 is Monday — first day of its ISO week.
        // Previous week = Dec 25–31 2023.
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 1, calendar: cal), calendar: cal)
        #expect(r.prevWeekStart == "2023-12-25")
        #expect(r.prevWeekEnd   == "2023-12-31")
    }

    // MARK: - Sunday-start locale (US calendar)

    /// On a Sunday the current week must START today, not include the whole previous Mon–Sun.
    /// This was the production bug: with ISO weeks, May 24 (Sunday) was the *last* day of the
    /// May 18–24 week and dragged in the full week's heavy spending.
    @Test func currentWeekStartIsToday_WhenTodayIsSunday() {
        let cal = sundayStartLocal()
        // May 24 2026 is Sunday.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 24, calendar: cal), calendar: cal)
        #expect(r.currentWeekStart == "2026-05-24", "Sunday must be the first day of the week, not the last")
        #expect(r.yesterdayDate    == "2026-05-23")
        #expect(r.todayDate        == "2026-05-24")
    }

    @Test func currentWeekStartIsLastSunday_WhenTodayIsWednesday() {
        let cal = sundayStartLocal()
        // May 27 2026 is Wednesday. The week started Sunday May 24.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 27, calendar: cal), calendar: cal)
        #expect(r.currentWeekStart == "2026-05-24")
        #expect(r.todayDate        == "2026-05-27")
    }

    @Test func currentWeekStartIsLastSunday_WhenTodayIsSaturday() {
        let cal = sundayStartLocal()
        // May 30 2026 is Saturday. Week started Sunday May 24.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 30, calendar: cal), calendar: cal)
        #expect(r.currentWeekStart == "2026-05-24")
        #expect(r.todayDate        == "2026-05-30")
    }

    @Test func previousWeekEndsYesterday_WhenTodayIsSunday() {
        let cal = sundayStartLocal()
        // May 24 2026 (Sunday) → previous week = May 17–23.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 24, calendar: cal), calendar: cal)
        #expect(r.prevWeekStart == "2026-05-17")
        #expect(r.prevWeekEnd   == "2026-05-23")
    }

    @Test func previousWeekMidWeek_SundayStart() {
        let cal = sundayStartLocal()
        // May 27 2026 (Wednesday) — same week as May 24 (Sunday).
        // Previous week = May 17–23.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 27, calendar: cal), calendar: cal)
        #expect(r.prevWeekStart == "2026-05-17")
        #expect(r.prevWeekEnd   == "2026-05-23")
    }

    /// Compared to ISO weeks, a Sunday-start calendar puts Sunday in a DIFFERENT week.
    /// This test makes the divergence explicit so a future refactor can't silently revert it.
    @Test func sundayBelongsToDifferentWeekThanISO() {
        let iso    = isoUTC()
        let sunday = sundayStartLocal()
        // May 24 2026 is Sunday.
        let now = date(year: 2026, month: 5, day: 24, calendar: sunday)
        let rISO    = PreviousPeriodDateRange.compute(relativeTo: now, calendar: iso)
        let rSunday = PreviousPeriodDateRange.compute(relativeTo: now, calendar: sunday)
        // ISO: Sunday is the last day of the Mon May 18–Sun May 24 week.
        #expect(rISO.currentWeekStart    == "2026-05-18")
        // Sunday-start: Sunday is the first day of the Sun May 24–Sat May 30 week.
        #expect(rSunday.currentWeekStart == "2026-05-24")
    }

    // MARK: - Timezone: todayDate must match the calendar's local date, not UTC

    /// After 5 pm US/Pacific on Sunday, UTC flips to Monday. Using UTC would make todayDate
    /// "2026-05-25" while Plaid transactions are still filed as "2026-05-24" locally.
    @Test func todayDateMatchesLocalNotUTC_LateEvening() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        fmt.timeZone = cal.timeZone
        // 6:30 pm PDT on May 24 = 1:30 am UTC May 25
        let localEvening = fmt.date(from: "2026-05-24 18:30")!

        let r = PreviousPeriodDateRange.compute(relativeTo: localEvening, calendar: cal)
        #expect(r.todayDate        == "2026-05-24", "todayDate must use local time, not UTC")
        #expect(r.currentWeekStart == "2026-05-24", "week must start on Sunday May 24, not Monday May 25")
    }

    // MARK: - Same-day comparison fields

    /// Day 1 of the current week → only day 1 of the previous week is included.
    /// Prevents the "+$2,586 vs last wk" phantom delta that appears on Sunday
    /// when currentWeekSpend = $11 (1 day) is compared to last week's full 7-day total.
    @Test func prevWeekSameDayEnd_WhenTodayIsFirstDayOfWeek() {
        let cal = sundayStartLocal()
        // May 24 2026 is Sunday (day 1 of the Sun-start week). Same-day end = May 17.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 24, calendar: cal), calendar: cal)
        #expect(r.prevWeekSameDayEnd == "2026-05-17", "day 1 of current week → day 1 of prev week")
    }

    @Test func prevWeekSameDayEnd_WhenTodayIsMidWeek() {
        let cal = sundayStartLocal()
        // May 27 2026 is Wednesday (day 4 of the Sun-start week). Same-day end = May 20.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 27, calendar: cal), calendar: cal)
        #expect(r.prevWeekSameDayEnd == "2026-05-20", "day 4 of current week → day 4 of prev week")
    }

    @Test func prevWeekSameDayEnd_WhenTodayIsLastDayOfWeek() {
        let cal = sundayStartLocal()
        // May 30 2026 is Saturday (day 7 of the Sun-start week). Same-day end = May 23 = prevWeekEnd.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 30, calendar: cal), calendar: cal)
        #expect(r.prevWeekSameDayEnd == "2026-05-23", "last day of current week → prevWeekSameDayEnd == prevWeekEnd")
    }

    @Test func prevMonthSameDayEnd_MidMonth() {
        let cal = sundayStartLocal()
        // May 24 2026 → April 24.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2026, month: 5, day: 24, calendar: cal), calendar: cal)
        #expect(r.prevMonthSameDayEnd == "2026-04-24")
    }

    @Test func prevMonthSameDayEnd_ClampsToLastDayOfShortMonth() {
        let cal = isoUTC()
        // March 31 2024, prev month = Feb 2024 (29 days, leap year) → clamp to Feb 29.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 3, day: 31, calendar: cal), calendar: cal)
        #expect(r.prevMonthSameDayEnd == "2024-02-29")
    }

    @Test func prevMonthSameDayEnd_WhenCurrentDayFitsInPrevMonth() {
        let cal = isoUTC()
        // March 15 2024 → Feb 15.
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 3, day: 15, calendar: cal), calendar: cal)
        #expect(r.prevMonthSameDayEnd == "2024-02-15")
    }

    // MARK: - Previous month

    @Test func previousMonthMidYear() {
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 5, day: 15, calendar: cal), calendar: cal)
        #expect(r.prevMonthStart == "2024-04-01")
        #expect(r.prevMonthEnd   == "2024-04-30")
    }

    @Test func previousMonthJanuaryWrapsToDecember() {
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 1, day: 15, calendar: cal), calendar: cal)
        #expect(r.prevMonthStart == "2023-12-01")
        #expect(r.prevMonthEnd   == "2023-12-31")
    }

    @Test func previousMonthLeapYear() {
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2024, month: 3, day: 1, calendar: cal), calendar: cal)
        #expect(r.prevMonthStart == "2024-02-01")
        #expect(r.prevMonthEnd   == "2024-02-29")
    }

    @Test func previousMonthNonLeapYear() {
        let cal = isoUTC()
        let r = PreviousPeriodDateRange.compute(relativeTo: date(year: 2023, month: 3, day: 1, calendar: cal), calendar: cal)
        #expect(r.prevMonthStart == "2023-02-01")
        #expect(r.prevMonthEnd   == "2023-02-28")
    }

    // MARK: - Stability with weird calendars (Suggestion C)

    @Test func stabilityWithNonStandardCalendars() {
        // Buddhist calendar, different firstWeekday, strange timezone
        var cal = Calendar(identifier: .buddhist)
        cal.firstWeekday = 4 // Wednesday
        cal.timeZone = TimeZone(identifier: "Asia/Kathmandu")!

        let now = Date()
        let r = PreviousPeriodDateRange.compute(relativeTo: now, calendar: cal)
        #expect(!r.todayDate.isEmpty)
        #expect(!r.currentWeekStart.isEmpty)
    }
}
