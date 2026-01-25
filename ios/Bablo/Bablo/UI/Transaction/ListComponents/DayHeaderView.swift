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
        // We need to compare the "nominal" date (YYYY-MM-DD from the DB)
        // against the user's "nominal" current date.
        
        // 1. Extract the nominal components from the transaction date (interpreted as UTC)
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let txComponents = utcCalendar.dateComponents([.year, .month, .day], from: day.date)
        
        // 2. Extract the nominal components for "Today" and "Yesterday" in Local time
        let localCalendar = Calendar.current
        let today = Date()
        let todayComponents = localCalendar.dateComponents([.year, .month, .day], from: today)
        
        // Check for Today
        if txComponents.year == todayComponents.year &&
           txComponents.month == todayComponents.month &&
           txComponents.day == todayComponents.day {
            return "Today"
        }
        
        // Check for Yesterday
        if let yesterday = localCalendar.date(byAdding: .day, value: -1, to: today) {
            let yesterdayComponents = localCalendar.dateComponents([.year, .month, .day], from: yesterday)
            
            if txComponents.year == yesterdayComponents.year &&
               txComponents.month == yesterdayComponents.month &&
               txComponents.day == yesterdayComponents.day {
                return "Yesterday"
            }
        }
        
        // Fallback: Just format the date
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: day.date)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
