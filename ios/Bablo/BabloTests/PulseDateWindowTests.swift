import Testing
import Foundation
@testable import Bablo

@Suite struct PulseDateWindowTests {

    private func utcCalendar() -> Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func pacificCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.timeZone = calendar.timeZone
        return calendar.date(from: comps)!
    }

    @Test func testCurrentDayRollover_UTCOffset() {
        // Local Time: Sunday, May 24, 2026 at 6:30 PM (18:30) PDT
        // UTC Time:   Monday, May 25, 2026 at 1:30 AM (01:30) UTC
        let localCal = pacificCalendar()
        let utcCal = utcCalendar()
        
        let testInstant = makeDate(year: 2026, month: 5, day: 24, hour: 18, minute: 30, calendar: localCal)
        
        // 1. Assert Legacy/UTC behavior:
        // Under a UTC calendar, the current day is May 25 (since UTC has already rolled over).
        let utcDayWindow = PulseDateWindow.current(period: .day, now: testInstant, calendar: utcCal)
        #expect(utcDayWindow.startDate == "2026-05-25")
        #expect(utcDayWindow.endDate == "2026-05-25")
        
        // 2. Assert Refactored/Local behavior:
        // Under a Pacific calendar, the current day remains May 24.
        let localDayWindow = PulseDateWindow.current(period: .day, now: testInstant, calendar: localCal)
        #expect(localDayWindow.startDate == "2026-05-24")
        #expect(localDayWindow.endDate == "2026-05-24")
    }

    @Test func testCurrentWeekWindow_UTCOffset() {
        // Local Time: Sunday, May 24, 2026 at 6:30 PM PDT
        let localCal = pacificCalendar()
        let utcCal = utcCalendar()
        
        let testInstant = makeDate(year: 2026, month: 5, day: 24, hour: 18, minute: 30, calendar: localCal)
        
        // Calendar-aligned week in UTC vs Local
        // Local calendar (Gregorian/US): week starts Sunday, May 24.
        // UTC calendar (ISO8601): testInstant is Monday, May 25 (UTC). Week starts Monday, May 25.
        let utcWeekWindow = PulseDateWindow.current(period: .week, now: testInstant, calendar: utcCal)
        #expect(utcWeekWindow.startDate == "2026-05-25")
        #expect(utcWeekWindow.endDate == "2026-05-25")
        
        let localWeekWindow = PulseDateWindow.current(period: .week, now: testInstant, calendar: localCal)
        #expect(localWeekWindow.startDate == "2026-05-24")
        #expect(localWeekWindow.endDate == "2026-05-24")
    }

    @Test func testCurrentWeekWindow_MidWeek() {
        // Local Time: Wednesday, May 27, 2026 at 10:00 AM PDT
        let localCal = pacificCalendar()
        let testInstant = makeDate(year: 2026, month: 5, day: 27, hour: 10, minute: 0, calendar: localCal)
        
        // Local calendar (Gregorian/US): week starts Sunday, May 24.
        let localWeekWindow = PulseDateWindow.current(period: .week, now: testInstant, calendar: localCal)
        #expect(localWeekWindow.startDate == "2026-05-24")
        #expect(localWeekWindow.endDate == "2026-05-27")
    }

    @Test func testCurrentMonthWindow_UTCOffset() {
        // Local Time: Sunday, May 24, 2026 at 6:30 PM PDT
        let localCal = pacificCalendar()
        let utcCal = utcCalendar()
        
        let testInstant = makeDate(year: 2026, month: 5, day: 24, hour: 18, minute: 30, calendar: localCal)
        
        let utcMonthWindow = PulseDateWindow.current(period: .month, now: testInstant, calendar: utcCal)
        #expect(utcMonthWindow.startDate == "2026-05-01")
        #expect(utcMonthWindow.endDate == "2026-05-25")
        
        let localMonthWindow = PulseDateWindow.current(period: .month, now: testInstant, calendar: localCal)
        #expect(localMonthWindow.startDate == "2026-05-01")
        #expect(localMonthWindow.endDate == "2026-05-24")
    }
}
