import Foundation

struct MerchantWeeklySpendData {
    let weekStart: Date
    let weekEnd: Date
    let totalSpent: Double
    let transactionCount: Int
    let isThisWeek: Bool
}

struct MerchantWeeklyDataProvider {
    let transactions: [Transaction]
    let currentTransaction: Transaction

    var weeklyData: [MerchantWeeklySpendData] {
        let calendar = Calendar.bablo
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<12).reversed().map { offset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: startOfThisWeek),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                return MerchantWeeklySpendData(weekStart: Date(), weekEnd: Date(), totalSpent: 0, transactionCount: 0, isThisWeek: offset == 0)
            }
            let txs = transactions.filter { tx in
                guard let date = TransactionDateParser.parsedDate(tx.spend_date ?? tx.authorized_date ?? tx.date) else { return false }
                return date >= weekStart && date < weekEnd
            }
            return MerchantWeeklySpendData(
                weekStart: weekStart,
                weekEnd: weekEnd,
                totalSpent: txs.reduce(0) { $0 + $1.absoluteAmount },
                transactionCount: txs.count,
                isThisWeek: offset == 0
            )
        }
    }

    var normalizedBars: [Double] {
        let values = weeklyData.map { $0.totalSpent }
        let maxValue = max(max(values.max() ?? currentTransaction.absoluteAmount, currentTransaction.absoluteAmount), 1)
        return values.map { $0 > 0 ? $0 / maxValue : 0 }
    }

    var hasPriorSpend: Bool {
        weeklyData.dropLast().contains { $0.totalSpent > 0.005 }
    }

    func weekLabel(for data: MerchantWeeklySpendData) -> String {
        if data.isThisWeek { return "this week" }
        let calendar = Calendar.bablo
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        let monthStr = monthFormatter.string(from: data.weekStart)
        let day = calendar.component(.day, from: data.weekStart)
        return "Week of \(monthStr) \(day)\(ordinalSuffix(for: day))"
    }

    private func ordinalSuffix(for day: Int) -> String {
        if (11...13).contains(day) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
