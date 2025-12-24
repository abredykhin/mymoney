//
//  DayHeaderView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/23/25.
//

import SwiftUI

struct DayHeaderView: View {
    let day: AllTransactionsView.DayKey
    let summary: AllTransactionsView.Summary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(formatDayHeader(day))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // Daily summary below the day name - separate lines
            if let summary = summary {
                if summary.totalIn > 0 {
                    HStack(spacing: 4) {
                        Text(formatAmount(summary.totalIn))
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if summary.totalOut > 0 {
                    HStack(spacing: 4) {
                        Text("-\(formatAmount(summary.totalOut))")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("out")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Loading state for stats
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Loading stats...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(height: 20)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .textCase(nil)
    }
    
    private func formatDayHeader(_ day: AllTransactionsView.DayKey) -> String {
        // Use UTC calendar for consistency
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        if calendar.isDateInToday(day.date) {
            return "Today"
        } else if calendar.isDateInYesterday(day.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: day.date)
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
