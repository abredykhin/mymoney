import Foundation

/// Computes date boundaries for the previous and current calendar week/month,
/// formatted as "yyyy-MM-dd" strings suitable for Supabase queries.
///
/// Uses the **device's local calendar and timezone** so that:
/// - Week boundaries respect the user's locale (Sunday-start in the US, Monday-start in Europe).
/// - Date strings match Plaid transaction dates, which are recorded in local time.
///
/// Using UTC here caused two bugs:
/// 1. In the US, ISO Mon-start weeks made Sunday the last day of the current week, dragging
///    in an entire week of prior spending even when Sunday itself was light.
/// 2. After the device crosses midnight locally (5 pm US/Pacific = UTC next day), the UTC
///    "today" jumped ahead, making current-day and current-week queries return 0 rows because
///    Plaid-dated transactions are still filed under the previous local date.
struct PreviousPeriodDateRange {
    let prevWeekStart: String
    let prevWeekEnd: String
    /// Previous week end clamped to the same number of days elapsed as the current week.
    /// Used for apples-to-apples delta comparison (avoids comparing 1 day vs 7 days on Sundays).
    let prevWeekSameDayEnd: String
    let prevMonthStart: String
    let prevMonthEnd: String
    /// Previous month end clamped to the same day-of-month as today (capped at the last day of that month).
    let prevMonthSameDayEnd: String
    let currentWeekStart: String
    let yesterdayDate: String
    let todayDate: String

    static func compute(relativeTo now: Date = Date(), calendar: Calendar = .current) -> PreviousPeriodDateRange {
        let cal = calendar   // already carries the device's locale and timezone

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone  // match the calendar's own timezone

        // Current calendar week (locale-aware: Sunday-start in the US)
        let currentWeekStartDate = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        // Previous calendar week
        let prevWeekStartDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStartDate) ?? currentWeekStartDate
        let prevWeekEndDate   = cal.date(byAdding: .day, value: -1, to: currentWeekStartDate) ?? currentWeekStartDate

        // Previous week same-day end: mirror the number of days elapsed this week.
        // On Sunday (day 1 of week) → prev week's Sunday only. On Saturday (day 7) → full prev week.
        let daysElapsedInWeek = (cal.dateComponents([.day], from: currentWeekStartDate, to: now).day ?? 0) + 1
        let prevWeekSameDayEndDate = cal.date(byAdding: .day, value: daysElapsedInWeek - 1, to: prevWeekStartDate) ?? prevWeekStartDate
        let yesterdayDate = cal.date(byAdding: .day, value: -1, to: now) ?? now

        // Previous calendar month
        let thisMonthStart     = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let prevMonthEndDate   = cal.date(byAdding: .day, value: -1, to: thisMonthStart) ?? thisMonthStart
        let prevMonthStartDate = cal.date(from: cal.dateComponents([.year, .month], from: prevMonthEndDate)) ?? prevMonthEndDate

        // Previous month same-day end: mirror the current day-of-month, capped at the prev month's length.
        let currentDayOfMonth = cal.component(.day, from: now)
        let daysInPrevMonth   = cal.range(of: .day, in: .month, for: prevMonthStartDate)?.count ?? 30
        var prevMonthSameDayComps = cal.dateComponents([.year, .month], from: prevMonthStartDate)
        prevMonthSameDayComps.day = min(currentDayOfMonth, daysInPrevMonth)
        let prevMonthSameDayEndDate = cal.date(from: prevMonthSameDayComps) ?? prevMonthStartDate

        return PreviousPeriodDateRange(
            prevWeekStart:        fmt.string(from: prevWeekStartDate),
            prevWeekEnd:          fmt.string(from: prevWeekEndDate),
            prevWeekSameDayEnd:   fmt.string(from: prevWeekSameDayEndDate),
            prevMonthStart:       fmt.string(from: prevMonthStartDate),
            prevMonthEnd:         fmt.string(from: prevMonthEndDate),
            prevMonthSameDayEnd:  fmt.string(from: prevMonthSameDayEndDate),
            currentWeekStart:     fmt.string(from: currentWeekStartDate),
            yesterdayDate:         fmt.string(from: yesterdayDate),
            todayDate:            fmt.string(from: now)
        )
    }
}
