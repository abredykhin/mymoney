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

func topBarDateLabel(for period: TopBarPeriodKind, calendar: Calendar = .current, now: Date = .init()) -> String {
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
