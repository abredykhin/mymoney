import Foundation

// MARK: - PulsePeriod + Sheet Labels

extension PulsePeriod {
    var swingPeriodLabel: String {
        switch self {
        case .day:   return "Day over day"
        case .week:  return "Week over week"
        case .month: return "Month over month"
        }
    }

    var previousPeriodLabel: String {
        switch self {
        case .day:   return "YESTERDAY"
        case .week:  return "LAST WK"
        case .month: return "LAST MO"
        }
    }

    var currentPeriodLabel: String {
        switch self {
        case .day:   return "TODAY"
        case .week:  return "THIS WK"
        case .month: return "THIS MO"
        }
    }

    var previousPeriodShortLabel: String {
        switch self {
        case .day:   return "yesterday"
        case .week:  return "last wk"
        case .month: return "last mo"
        }
    }

    var currentPeriodShortLabel: String {
        switch self {
        case .day:   return "today"
        case .week:  return "this wk"
        case .month: return "this mo"
        }
    }

    var currentWindowLabel: String {
        displayLabel(for: currentWindow)
    }

    var previousWindowLabel: String {
        guard let comparisonWindow else { return "" }
        return displayLabel(for: comparisonWindow)
    }

    var cushionSubtitle: String {
        switch self {
        case .day:
            return "\(currentWindowLabel) vs yesterday"
        case .week:
            return "\(currentWindowLabel) vs the week before"
        case .month:
            return "\(currentWindowLabel) vs last month"
        }
    }

    func swingSubtitle(report: PulseDamageReport) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = Calendar.bablo.timeZone

        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = Calendar.bablo.timeZone

        switch self {
        case .day:
            guard let start = fmt.date(from: report.startDate) else { return "Today vs yesterday" }
            display.dateFormat = "MMM d"
            return "\(display.string(from: start)) vs yesterday"

        case .week:
            guard
                let start = fmt.date(from: report.startDate),
                let end   = fmt.date(from: report.endDate)
            else { return "This week vs last" }
            display.dateFormat = "MMM d"
            return "\(display.string(from: start)) – \(display.string(from: end)) vs the week before"

        case .month:
            guard let start = fmt.date(from: report.startDate) else { return "This month vs last" }
            display.dateFormat = "MMMM"
            let prev = Calendar.bablo.date(byAdding: .month, value: -1, to: start)
            let prevName = prev.map { display.string(from: $0) } ?? "last month"
            return "\(display.string(from: start)) vs \(prevName)"
        }
    }

    func currentDateRangeLabel(report: PulseDamageReport) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = Calendar.bablo.timeZone
        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = Calendar.bablo.timeZone
        display.dateFormat = "MMM d"

        switch self {
        case .day:
            return fmt.date(from: report.startDate).map { display.string(from: $0) } ?? ""
        case .week:
            guard let s = fmt.date(from: report.startDate), let e = fmt.date(from: report.endDate) else { return "" }
            return "\(display.string(from: s)) – \(display.string(from: e))"
        case .month:
            guard let s = fmt.date(from: report.startDate) else { return "" }
            display.dateFormat = "MMMM"
            return display.string(from: s)
        }
    }

    func previousDateRangeLabel(report: PulseDamageReport) -> String {
        guard let win = comparisonWindow else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = Calendar.bablo.timeZone
        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = Calendar.bablo.timeZone
        display.dateFormat = "MMM d"

        switch self {
        case .day:
            return fmt.date(from: win.startDate).map { display.string(from: $0) } ?? ""
        case .week:
            guard let s = fmt.date(from: win.startDate), let e = fmt.date(from: win.endDate) else { return "" }
            return "\(display.string(from: s)) – \(display.string(from: e))"
        case .month:
            guard let s = fmt.date(from: win.startDate) else { return "" }
            display.dateFormat = "MMMM"
            return display.string(from: s)
        }
    }

    private func displayLabel(for window: PulseDateWindow) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = Calendar.bablo.timeZone

        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = Calendar.bablo.timeZone
        display.dateFormat = "MMM d"

        guard let start = fmt.date(from: window.startDate) else { return "" }

        switch self {
        case .day:
            return display.string(from: start)
        case .week:
            guard let end = fmt.date(from: window.endDate) else { return display.string(from: start) }
            return "\(display.string(from: start)) - \(display.string(from: end))"
        case .month:
            display.dateFormat = "MMMM"
            return display.string(from: start)
        }
    }
}
