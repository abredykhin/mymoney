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
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(formatDayHeader(day))
                .font(Typography.bodySemibold)
                .foregroundColor(ColorPalette.textPrimary)

            // Daily summary below the day name - separate lines
            if let summary = summary {
                if summary.totalIn > 0 {
                    HStack(spacing: Spacing.xs) {
                        Text(formatAmount(summary.totalIn))
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.success)
                        Text("in")
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }

                if summary.totalOut > 0 {
                    HStack(spacing: Spacing.xs) {
                        Text("-\(formatAmount(summary.totalOut))")
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.error)
                        Text("out")
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            } else {
                // Loading state for stats
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Loading stats...")
                        .font(Typography.footnote)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .frame(height: 20)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.backgroundSecondary)
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
