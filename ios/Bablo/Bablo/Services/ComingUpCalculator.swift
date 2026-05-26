//
//  ComingUpCalculator.swift
//  Bablo
//

import Foundation

struct ComingUpCalculator {
    let subscriptions: [RecurringStream]
    let currentDate: Date
    let timeZone: TimeZone

    init(subscriptions: [RecurringStream], currentDate: Date = Date(), timeZone: TimeZone = TimeZone(identifier: "UTC")!) {
        self.subscriptions = subscriptions
        self.currentDate = currentDate
        self.timeZone = timeZone
    }

    func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.date(from: dateString)
    }

    func daysRemaining(for targetDate: Date) -> Int {
        var calendar = Calendar.bablo
        calendar.timeZone = timeZone
        let startOfCurrent = calendar.startOfDay(for: currentDate)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfCurrent, to: startOfTarget)
        return components.day ?? 0
    }

    func daysRemaining(for stream: RecurringStream) -> Int? {
        guard let dateStr = stream.predictedNextDate,
              let parsedDate = parseDate(dateStr) else {
            return nil
        }
        return daysRemaining(for: parsedDate)
    }

    func dayOfWeekDisplay(for targetDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = timeZone
        return formatter.string(from: targetDate)
    }

    func badgeText(for days: Int) -> String {
        if days == 0 {
            return "TODAY"
        } else if days == 1 {
            return "IN 1D"
        } else if days > 1 {
            return "IN \(days)D"
        } else {
            return ""
        }
    }

    func upcomingBills(withinDays daysLimit: Int = 14) -> [RecurringStream] {
        return subscriptions.filter { stream in
            guard stream.isActive && !stream.isExcluded && stream.type == "expense" else {
                return false
            }
            guard let days = daysRemaining(for: stream) else {
                return false
            }
            return days >= 0 && days <= daysLimit
        }.sorted { a, b in
            let daysA = daysRemaining(for: a) ?? Int.max
            let daysB = daysRemaining(for: b) ?? Int.max
            return daysA < daysB
        }
    }
}
