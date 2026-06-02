//
//  Dates.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/24/24.
//

import SwiftUI

// Helper method for date formatting
func formatDate(_ dateString: String, inputFormat: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ", outputFormat: DateFormatter.Style = .medium) -> String {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = inputFormat

    let outputFormatter = DateFormatter()
    outputFormatter.dateStyle = outputFormat

    if let date = inputFormatter.date(from: dateString) {
        return outputFormatter.string(from: date)
    } else {
        return dateString // Fallback if date conversion fails
    }
}

// Compact date formatting for transaction lists (e.g., "Jan 25")
func formatDateShort(_ dateString: String, inputFormat: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ") -> String {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = inputFormat

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "MMM d"

    if let date = inputFormatter.date(from: dateString) {
        return outputFormatter.string(from: date)
    } else {
        return dateString // Fallback if date conversion fails
    }
}

// Shared top-bar date range label used by Home and Pulse tabs.
enum TopBarPeriodKind { case day, week, month }

func topBarDateLabel(for period: TopBarPeriodKind, calendar: Calendar = .bablo, now: Date = .init()) -> String {
    switch period {
    case .day:
        return "TODAY"

    case .week:
        // weekday: 1 = Sunday … 7 = Saturday
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 {
            // First day of the week — show full name so "SUN → SUN" is avoided
            return fullDayFormatter.string(from: now).uppercased()
        }
        let daysBack = weekday - 1 // days since last Sunday
        let sunday = calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
        return shortDayFormatter.string(from: sunday).uppercased()
             + " → "
             + shortDayFormatter.string(from: now).uppercased()

    case .month:
        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = 1
        let firstOfMonth = calendar.date(from: comps) ?? now
        if calendar.isDate(now, inSameDayAs: firstOfMonth) {
            // First day of the month — show the month name so "JUN 1 → JUN 1" is avoided
            return monthNameFormatter.string(from: now).uppercased()
        }
        return monthDayFormatter.string(from: firstOfMonth).uppercased()
             + " → "
             + monthDayFormatter.string(from: now).uppercased()
    }
}

private let shortDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE"   // "Sun", "Mon", …
    return f
}()

private let fullDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE"  // "Sunday", …
    return f
}()

private let monthDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d" // "May 23"
    return f
}()

private let monthNameFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMMM" // "June"
    return f
}()

// MARK: - Central Calendar Configuration
extension Calendar {
    /// The single source of truth for all calendar calculations in the Bablo application.
    ///
    /// This standardizes on the Gregorian calendar to prevent formatting errors
    /// on devices set to non-Gregorian system calendars (like the Buddhist or Japanese calendars),
    /// while fully respecting the user's local TimeZone and Locale settings.
    public static var bablo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }
}
