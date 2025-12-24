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
        VStack(alignment: .leading, spacing: 2) {
            Text(formatMonthHeader(month))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if let summary = summary {
                // "In" amount on first line (if > 0)
                if summary.totalIn > 0 {
                    HStack(spacing: 4) {
                        Text(formatAmount(summary.totalIn))
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Text("in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // "Out" amount on second line (if > 0)
                if summary.totalOut > 0 {
                    HStack(spacing: 4) {
                        Text("-\(formatAmount(summary.totalOut))")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("out")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Loading state for monthly stats
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Calculating totals...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 30)
            }
        }
        .padding(.vertical, 8)
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
