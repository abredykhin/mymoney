//
//  ComingUpCalculator.swift
//  Bablo
//

import Foundation

struct ComingUpCalculator {
    let subscriptions: [RecurringStream]
    let currentDate: Date
    let timeZone: TimeZone
    /// Latest spend date (yyyy-MM-dd) per lowercased merchant name, used to suppress
    /// bills whose current occurrence has already posted (see `isPaidThisCycle`).
    let recentPaymentDates: [String: String]

    init(
        subscriptions: [RecurringStream],
        currentDate: Date = Date(),
        timeZone: TimeZone = TimeZone(identifier: "UTC")!,
        recentPaymentDates: [String: String] = [:]
    ) {
        self.subscriptions = subscriptions
        self.currentDate = currentDate
        self.timeZone = timeZone
        self.recentPaymentDates = recentPaymentDates
    }

    /// How many days of slack around the predicted date count as "this occurrence
    /// already posted." Scaled by cadence so a weekly bill paid last week is not
    /// mistaken for this week's, while a monthly bill paid a few days early still is.
    private func paidToleranceDays(for frequency: String) -> Int {
        switch frequency.uppercased() {
        case "WEEKLY":       return 3
        case "SEMI_MONTHLY": return 5
        case "MONTHLY":      return 10
        case "ANNUALLY":     return 20
        default:             return 7
        }
    }

    /// True when a transaction matching this stream's merchant has posted close enough
    /// to the predicted date that the upcoming occurrence is already covered. This
    /// catches bills (e.g. rent) that posted a few days before Plaid advanced the
    /// stream's predicted_next_date, so they shouldn't show as "due soon" / "coming up".
    func isPaidThisCycle(_ stream: RecurringStream) -> Bool {
        guard let predictedStr = stream.predictedNextDate,
              let predicted = parseDate(predictedStr),
              let merchant = stream.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !merchant.isEmpty,
              let paidStr = recentPaymentDates[merchant],
              let paid = parseDate(paidStr) else {
            return false
        }
        var calendar = Calendar.bablo
        calendar.timeZone = timeZone
        let dayDiff = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: predicted),
            to: calendar.startOfDay(for: paid)
        ).day ?? Int.max
        return abs(dayDiff) <= paidToleranceDays(for: stream.frequency)
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
            // Hide bills whose current occurrence already posted (e.g. rent paid a few
            // days before Plaid advanced predicted_next_date).
            guard !isPaidThisCycle(stream) else {
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
