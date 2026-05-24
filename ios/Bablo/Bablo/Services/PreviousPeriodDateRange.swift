import Foundation

/// Computes the start/end dates for the previous calendar week and previous calendar month,
/// formatted as "yyyy-MM-dd" strings suitable for Supabase queries.
///
/// "Previous week" means the last complete Mon–Sun (or locale-defined) calendar week
/// before the week that contains `now` — NOT a rolling 7-day window.
struct PreviousPeriodDateRange {
    let prevWeekStart: String
    let prevWeekEnd: String
    let prevMonthStart: String
    let prevMonthEnd: String

    // ISO 8601 calendar: weeks start Monday, matches Plaid/Supabase date conventions
    static func compute(relativeTo now: Date = Date(), calendar: Calendar = Calendar(identifier: .iso8601)) -> PreviousPeriodDateRange {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC")!

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!

        // Previous calendar week: the week before the week containing `now`
        let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let prevWeekStartDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        // End = one day before current week started
        let prevWeekEndDate = cal.date(byAdding: .day, value: -1, to: currentWeekStart)!

        // Previous calendar month: full month before the month containing `now`
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let prevMonthEndDate = cal.date(byAdding: .day, value: -1, to: thisMonthStart)!
        let prevMonthStartDate = cal.date(from: cal.dateComponents([.year, .month], from: prevMonthEndDate))!

        return PreviousPeriodDateRange(
            prevWeekStart: fmt.string(from: prevWeekStartDate),
            prevWeekEnd: fmt.string(from: prevWeekEndDate),
            prevMonthStart: fmt.string(from: prevMonthStartDate),
            prevMonthEnd: fmt.string(from: prevMonthEndDate)
        )
    }
}
