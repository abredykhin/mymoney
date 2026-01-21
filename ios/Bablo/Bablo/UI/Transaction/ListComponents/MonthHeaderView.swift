//
//  MonthHeaderView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/23/25.
//

import SwiftUI

struct MonthHeaderView: View {
    let month: AllTransactionsView.MonthKey
    let summary: AllTransactionsView.Summary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(formatMonthHeader(month))
                .font(Typography.h4)
                .fontWeight(.bold)
                .foregroundColor(ColorPalette.textPrimary)

            if let summary = summary {
                // "In" amount on first line (if > 0)
                if summary.totalIn > 0 {
                    HStack(spacing: Spacing.xs) {
                        Text(formatAmount(summary.totalIn))
                            .font(Typography.bodyMedium)
                            .foregroundColor(ColorPalette.success)
                        Text("in")
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }

                // "Out" amount on second line (if > 0)
                if summary.totalOut > 0 {
                    HStack(spacing: Spacing.xs) {
                        Text("-\(formatAmount(summary.totalOut))")
                            .font(Typography.bodyMedium)
                            .foregroundColor(ColorPalette.error)
                        Text("total spent (includes bills)")
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            } else {
                // Loading state for monthly stats
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Calculating totals...")
                        .font(Typography.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .frame(height: 30)
            }
        }
        .padding(.vertical, Spacing.sm)
        .textCase(nil)
    }
    
    private func formatMonthHeader(_ month: AllTransactionsView.MonthKey) -> String {
        let dateComponents = DateComponents(year: month.year, month: month.month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return "Unknown"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
