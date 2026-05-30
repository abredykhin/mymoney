//
//  ComingUpCalculatorTests.swift
//  BabloTests
//

import Testing
import Foundation
@testable import Bablo

@Suite("ComingUpCalculator")
struct ComingUpCalculatorTests {
    
    private let timeZone = TimeZone(identifier: "UTC")!
    
    // Sat May 23, 2026
    private var baseDate: Date {
        let components = DateComponents(year: 2026, month: 5, day: 23, hour: 12, minute: 0, second: 0)
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.date(from: components)!
    }
    
    private func createStream(id: Int, name: String, nextDate: String?) -> RecurringStream {
        RecurringStream(
            id: id,
            plaidStreamId: "plaid_\(id)",
            description: name,
            merchantName: name,
            personalFinanceCategory: "UTILITIES",
            personalFinanceSubcategory: nil,
            frequency: "MONTHLY",
            averageAmount: 10.0,
            monthlyAmount: 10.0,
            isoCurrencyCode: "USD",
            type: "expense",
            status: "MATURE",
            isActive: true,
            firstDate: nil,
            lastDate: nil,
            predictedNextDate: nextDate,
            isUserModified: false,
            userMarkedRecurring: nil,
            isExcluded: false,
            isManual: false,
            matchPattern: nil,
            accountId: nil
        )
    }
    
    @Test func testParseDate() {
        let calc = ComingUpCalculator(subscriptions: [], currentDate: baseDate, timeZone: timeZone)
        let parsed = calc.parseDate("2026-05-25")
        #expect(parsed != nil)
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: parsed!)
        #expect(components.year == 2026)
        #expect(components.month == 5)
        #expect(components.day == 25)
    }
    
    @Test func testDaysRemaining() {
        let calc = ComingUpCalculator(subscriptions: [], currentDate: baseDate, timeZone: timeZone)
        
        // Target: same day -> 0 days
        let todayTarget = calc.parseDate("2026-05-23")!
        #expect(calc.daysRemaining(for: todayTarget) == 0)
        
        // Target: tomorrow -> 1 day
        let tomorrowTarget = calc.parseDate("2026-05-24")!
        #expect(calc.daysRemaining(for: tomorrowTarget) == 1)
        
        // Target: yesterday -> -1 day
        let yesterdayTarget = calc.parseDate("2026-05-22")!
        #expect(calc.daysRemaining(for: yesterdayTarget) == -1)
        
        // Target: in 6 days -> 6 days
        let target6Days = calc.parseDate("2026-05-29")!
        #expect(calc.daysRemaining(for: target6Days) == 6)
    }
    
    @Test func testBadgeText() {
        let calc = ComingUpCalculator(subscriptions: [], currentDate: baseDate, timeZone: timeZone)
        
        #expect(calc.badgeText(for: 0) == "TODAY")
        #expect(calc.badgeText(for: 1) == "IN 1D")
        #expect(calc.badgeText(for: 2) == "IN 2D")
        #expect(calc.badgeText(for: 14) == "IN 14D")
        #expect(calc.badgeText(for: -1) == "")
    }
    
    @Test func testDayOfWeekDisplay() {
        let calc = ComingUpCalculator(subscriptions: [], currentDate: baseDate, timeZone: timeZone)
        
        // May 23, 2026 is Saturday
        let sat = calc.parseDate("2026-05-23")!
        #expect(calc.dayOfWeekDisplay(for: sat) == "Sat")
        
        // May 25, 2026 is Monday
        let mon = calc.parseDate("2026-05-25")!
        #expect(calc.dayOfWeekDisplay(for: mon) == "Mon")
    }
    
    @Test func testUpcomingBillsFilteringAndSorting() {
        let streams = [
            createStream(id: 1, name: "Spotify", nextDate: "2026-05-25"), // In 2 days (Mon) - Keep
            createStream(id: 2, name: "Rent", nextDate: "2026-05-29"),    // In 6 days (Fri) - Keep
            createStream(id: 3, name: "Verizon", nextDate: "2026-06-15"), // In 23 days - Filter out (>14 days)
            createStream(id: 4, name: "Past Bill", nextDate: "2026-05-20") // Past - Filter out
        ]
        
        let calc = ComingUpCalculator(subscriptions: streams, currentDate: baseDate, timeZone: timeZone)
        let upcoming = calc.upcomingBills(withinDays: 14)
        
        #expect(upcoming.count == 2)
        #expect(upcoming[0].merchantName == "Spotify")
        #expect(upcoming[1].merchantName == "Rent")
    }
    
    @Test func testDaysRemaining_UTCOffset_Evening() {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        let utcTimeZone = TimeZone(identifier: "UTC")!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = laTimeZone
        
        // Sunday May 24, 2026 at 6:30 PM (18:30) PDT = Monday May 25, 2026 at 1:30 AM UTC
        let eveningDate = formatter.date(from: "2026-05-24 18:30")!
        
        let billStream = createStream(id: 1, name: "Legit Bill", nextDate: "2026-05-27")
        
        // 1. In UTC timezone, because current day rolled over to May 25th, days remaining should be 2:
        let utcCalc = ComingUpCalculator(subscriptions: [billStream], currentDate: eveningDate, timeZone: utcTimeZone)
        #expect(utcCalc.daysRemaining(for: billStream) == 2)
        
        // 2. In Local Pacific timezone, current day remains May 24th, so days remaining should be 3:
        let laCalc = ComingUpCalculator(subscriptions: [billStream], currentDate: eveningDate, timeZone: laTimeZone)
        #expect(laCalc.daysRemaining(for: billStream) == 3)
    }
}
