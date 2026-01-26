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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(formatMonthHeader(month))
                .font(Typography.h4)
                .fontWeight(.bold)
                .foregroundColor(ColorPalette.textPrimary)

            if let summary = summary {
                HStack(spacing: Spacing.md) {
                    // "In" amount (if > 0)
                    if summary.totalIn > 0 {
                        HStack(spacing: Spacing.xxs) {
                            Text(formatAmount(summary.totalIn))
                                .font(Typography.caption)
                                .foregroundColor(ColorPalette.success)
                            Text("in")
                                .font(Typography.footnote)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }

                    // "Out" amount (if > 0)
                    if summary.totalOut > 0 {
                        HStack(spacing: Spacing.xxs) {
                            Text(formatAmount(summary.totalOut))
                                .font(Typography.caption)
                                .foregroundColor(ColorPalette.error)
                            Text("spent")
                                .font(Typography.footnote)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                }
            } else {
                // Loading state for monthly stats
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(Typography.footnote)
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .padding(.horizontal, Spacing.xs)
        .listRowInsets(EdgeInsets())
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
