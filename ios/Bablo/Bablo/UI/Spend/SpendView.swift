//
//  SpendView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 4/6/25.
//

import SwiftUI

// Helper for currency formatting
extension NumberFormatter {
    static func currency(code: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter
    }
}

struct SpendView : View {
    @State private var selectedDateRange: SpendDateRange = .week
    @StateObject private var budgetService = BudgetService()
    
    // Determine which value to display based on the selected range
    private func spendValue(for item: CategoryBreakdownItem, range: SpendDateRange) -> Double {
        switch range {
        case .week:
            return item.weekly_spend
        case .month:
            return item.monthly_spend
        case .year:
            return item.yearly_spend
        }
    }
    
    var body: some View {
        // Use a NavigationStack or NavigationView if this is part of a larger flow
        ScrollView {
            VStack(alignment: .leading) {
                // Use the SpendDateRange's displayName
                Picker("Date range", selection: $selectedDateRange) {
                    ForEach(SpendDateRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom)
                
                // Show loading or error state
                if budgetService.isLoadingBreakdown {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let error = budgetService.breakdownError {
                    Text("Error loading breakdown: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                } else if budgetService.spendBreakdownItems.isEmpty {
                    Text("No spending data available for the current year.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Display the data using LazyVStack
                    LazyVStack(spacing: 15) {
                        ForEach(
                            budgetService.spendBreakdownItems,
                            id: \.category
                        ) { item in
                            HStack {
                                Text(item.category)
                                Spacer()
                                Text(
                                    spendValue(
                                        for: item,
                                        range: selectedDateRange
                                    ),
                                     format: .currency(code: "USD")
                                )
                                .monospaced()
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        // Use .task to fetch data when the view appears (or relevant data changes)
        .task {
            // Fetch initial data when the view appears
            // You can choose a default week start day here or get it from user prefs
            try? await budgetService.fetchSpendBreakdown(period: .week)
        }
        .navigationTitle("Spend")
    }
}
